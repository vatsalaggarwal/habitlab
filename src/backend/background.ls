window.addEventListener "unhandledrejection", (evt) ->
  throw new Error(evt.reason)

do ->>
  localStorage.removeItem 'cached_list_all_goals'
  localStorage.removeItem 'cached_list_all_interventions'
  localStorage.removeItem 'cached_list_generic_interventions'
  localStorage.removeItem 'cached_get_goals'
  localStorage.removeItem 'cached_get_interventions'
  localStorage.removeItem 'baseline_session_time_on_domains'
  localStorage.removeItem 'baseline_time_on_domains'

  window.global_exports = {}

  dlog = window.dlog = (...args) ->
    if localStorage.getItem('display_dlog') == 'true'
      console.log(...args)

  {
    addtokey_dictdict
    getkey_dictdict
    getDb
  } = require 'libs_backend/db_utils'

  await getDb()

  require! {
    localforage
  }

  chrome_manifest = chrome.runtime.getManifest()
  habitlab_version = chrome_manifest.version
  developer_mode = not chrome_manifest.update_url?
  unofficial_version = chrome.runtime.id != 'obghclocpdgcekcognpkblghkedcpdgd'

  if (not developer_mode) or localStorage.getItem('devmode_use_cache') == 'true'
    need_to_clear_cache = localStorage.getItem('devmode_clear_cache_on_reload') == 'true'
    if need_to_clear_cache or (not developer_mode) # installed from chrome web store
      store = localforage.createInstance({
        name: 'localget'
      })
      if not need_to_clear_cache
        if (not developer_mode)
          version_cached = await store.getItem('habitlab_version')
          if version_cached != habitlab_version
            need_to_clear_cache = true
      if need_to_clear_cache
        await store.clear()
        await store.setItem('habitlab_version', habitlab_version)

  require 'libs_backend/systemjs'

  {
    get_goals
    get_enabled_goals
    get_goal_target
    get_goal_intervention_info
    set_goals_enabled
    set_default_goals_enabled
  } = require 'libs_backend/goal_utils'

  {
    send_message_to_active_tab
    send_message_to_tabid
    get_active_tab_info
    get_user_id
    get_user_secret
    list_currently_loaded_interventions_for_tabid
  } = require 'libs_backend/background_common'

  $ = require 'jquery'

  {
    send_logging_enabled
    get_basic_client_data
  } = require 'libs_backend/logging_enabled_utils'

  {yfy} = require 'cfy'

  export make_tab_focused = (tab_id, window_id) ->>
    await new Promise -> chrome.windows.update(window_id, {focused: true}, it)
    await new Promise -> chrome.tabs.update(tab_id, {active: true}, it)

  export focus_tab_by_pattern_if_available = (url_pattern) ->>
    all_tab_list = await new Promise -> chrome.tabs.query {url: url_pattern}, it
    if all_tab_list.length == 0
      return false
    candidate_list = all_tab_list.filter (.currentWindow)
    if candidate_list.length > 0
      all_tab_list = candidate_list
    candidate_list = all_tab_list.filter (.active)
    if candidate_list.length > 0
      all_tab_list = candidate_list
    tab_info = all_tab_list[0]
    await make_tab_focused(tab_info.id, tab_info.windowId)
    return true

  num_times_notification_already_shown = 0
  num_times_to_pause_before_next_notification = 0
  export show_finish_configuring_notification_if_needed = ->>
    if localStorage.getItem('allow_logging')?
      return
    tabs_list = await new Promise -> chrome.tabs.query {url: chrome.extension.getURL('/options.html')}, it
    if tabs_list.length > 0
      return
    if num_times_to_pause_before_next_notification > 0 # decreases frequency of notification exponentially to decrease annoyingness
      num_times_to_pause_before_next_notification := num_times_to_pause_before_next_notification - 1
      if num_times_to_pause_before_next_notification > 0
        return
    num_times_notification_already_shown := num_times_notification_already_shown + 1
    num_times_to_pause_before_next_notification := Math.pow(2, num_times_notification_already_shown + 1)
    notification = new Notification 'Finish setting up HabitLab', {
      icon: chrome.extension.getURL('icons/icon_128.png')
      body: 'Click here to finish setting up HabitLab'
      requireInteraction: true
    }
    close_notification = notification.close.bind(notification)
    notification.onclick = ->
      chrome.tabs.create({url: chrome.extension.getURL('options.html#onboarding:last')})
      close_notification()

  export get_last_visit_to_website_timestamp = ->>
    history_search_results = await new Promise -> chrome.history.search({text: 'https://habitlab.stanford.edu', startTime: 0}, it)
    last_visit_timestamp = -1
    for search_result in history_search_results
      if search_result.url.startsWith('https://habitlab.stanford.edu')
        if search_result.lastVisitTime > last_visit_timestamp
          last_visit_timestamp = search_result.lastVisitTime
    return last_visit_timestamp

  export get_last_visit_to_chrome_store_timestamp = ->>
    history_search_results = await new Promise -> chrome.history.search({text: 'https://chrome.google.com/webstore/detail/habitlab/obghclocpdgcekcognpkblghkedcpdgd', startTime: 0}, it)
    last_visit_timestamp = -1
    for search_result in history_search_results
      if search_result.url.startsWith('https://chrome.google.com/webstore/detail/habitlab/obghclocpdgcekcognpkblghkedcpdgd')
        if search_result.lastVisitTime > last_visit_timestamp
          last_visit_timestamp = search_result.lastVisitTime
    return last_visit_timestamp

  do ->>
    # open the options page on first run
    if localStorage.getItem('notfirstrun')
      if not localStorage.getItem('allow_logging')? # user did not complete onboarding
        show_finish_configuring_notification_if_needed()
        #setInterval ->
        #  show_finish_configuring_notification_if_needed()
        #, 20000
        #chrome.tabs.create {url: 'options.html#onboarding:last'}
        #localStorage.setItem('allow_logging_on_default_without_onboarding', true)
        #localStorage.setItem('allow_logging', true)
        #send_logging_enabled {page: 'background', manual: false, 'allow_logging_on_default_without_onboarding': true}
      return
    localStorage.setItem('notfirstrun', true)
    await set_default_goals_enabled()
    user_id = await get_user_id()
    tab_info = await get_active_tab_info()
    last_visit_to_website_timestamp = await get_last_visit_to_website_timestamp()
    last_visit_to_chrome_store_timestamp = await get_last_visit_to_chrome_store_timestamp()
    need_to_create_new_tab = true
    install_source = 'unknown'
    if tab_info?
      if tab_info.url == 'https://habitlab.netlify.com/#installing' or tab_info.url == 'https://habitlab.stanford.edu/#installing' or tab_info.url == 'https://habitlab.github.io/#installing' or tab_info.url == 'http://habitlab.netlify.com/#installing' or tab_info.url == 'http://habitlab.stanford.edu/#installing' or tab_info.url == 'http://habitlab.github.io/#installing'
        install_source = tab_info.url
        #need_to_create_new_tab = false
        #chrome.tabs.executeScript(tab_info.id, {code: 'window.location.href = "' + chrome.extension.getURL('options.html#onboarding') + '"'})
    if need_to_create_new_tab
      if install_source == 'unknown'
        if developer_mode
          install_source = 'sideload'
        else
          install_source = 'webstore'
      chrome.tabs.create {url: 'options.html#onboarding'}
    install_data = await get_basic_client_data()
    install_data.install_source = install_source
    install_data.last_visit_to_website = last_visit_to_website_timestamp
    install_data.last_visit_to_chrome_store = last_visit_to_chrome_store_timestamp
    $.ajax {
      type: 'POST'
      url: 'https://habitlab.herokuapp.com/add_install'
      dataType: 'json'
      contentType: 'application/json'
      data: JSON.stringify(install_data)
    }
    user_secret = await get_user_secret()
    $.ajax {
      type: 'POST'
      url: 'https://habitlab.herokuapp.com/add_secret'
      dataType: 'json'
      contentType: 'application/json'
      data: JSON.stringify({user_id, user_secret})
    }
    setInterval ->
      show_finish_configuring_notification_if_needed()
    , 5000

  {
    get_all_message_handlers
  } = require 'libs_backend/expose_lib'

  require 'libs_backend/expose_backend_libs'

  {localget, remoteget} = require 'libs_common/cacheget_utils'

  {
    start_syncing_all_data
  } = require 'libs_backend/log_sync_utils'

  {
    get_interventions
    list_enabled_nonconflicting_interventions_for_location
    list_all_enabled_interventions_for_location
    list_available_interventions_for_location
    get_intervention_parameters
    is_it_outside_work_hours
  } = require 'libs_backend/intervention_utils'

  {
    make_wait_token
    wait_for_token
    finished_waiting
  } = require 'libs_common/wait_utils'

  {
    get_days_since_epoch
  } = require 'libs_common/time_utils'

  {
    get_new_session_id_for_domain
  } = require 'libs_common/time_spent_utils'

  {
    url_to_domain
  } = require 'libs_common/domain_utils'

  {
    add_tab_navigation_event
  } = require 'libs_backend/session_utils'

  {
    run_every_timeperiod
  } = require 'libs_common/common_libs'

  {
    as_array
    as_dictset
  } = require 'libs_common/collection_utils'

  {
    localstorage_getjson
    localstorage_setjson
    localstorage_getbool
  } = require 'libs_common/localstorage_utils'

  {
    baseline_time_per_session_for_domain
  } = require 'libs_common/gamification_utils'

  require! {
    moment
    'promise-debounce'
  }

  {
    gexport
    gexport_module
  } = require 'libs_common/gexport'

  {
    set_active_interventions_for_domain_and_session
  } = require 'libs_backend/intervention_manager'

  {
    get_progress_on_enabled_goals_today
    get_progress_on_goal_this_week
  } = require 'libs_backend/goal_progress'

  {
    is_habitlab_enabled_sync
  } = require 'libs_backend/disable_habitlab_utils'

  {
    ensure_history_utils_data_cached
  } = require 'libs_common/history_utils'

  {
    log_impression_internal
  } = require 'libs_backend/log_utils'

  {
    sleep
  } = require 'libs_common/common_libs'

  # require 'libs_common/measurement_utils'

  # dlog 'weblab running in background'
  # alert('hello');

  /*
  execute_content_script = (tabid, options, callback) ->
    #chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
    if not tabid?
      if callback?
        callback()
      return
    chrome.tabs.executeScript tabid, {file: options.path, allFrames: options.all_frames, runAt: options.run_at}, ->
      if callback?
        callback()
  */

  insert_css = (css_path) ->>
    # todo does not do anything currently
    return

  running_background_scripts = {}

  load_background_script = (options, intervention_info) ->>
    if running_background_scripts[options.path]?
      # already running
      return
    if options.code?
      background_script_text = options.code
    else
      background_script_text = await localget(options.path)
    background_script_function = new Function('env', background_script_text)
    env = {
      intervention_info: intervention_info
    }
    background_script_function(env)
    running_background_scripts[options.path] = env
    return

  cached_systemjs_code = null

  execute_content_scripts_for_intervention = (intervention_info, tabId, intervention_list) ->>
    {content_script_options, name} = intervention_info

    # do not put here, because it may generate duplicates if the page causes the intervention to try to load multiple times
    # log_impression_internal(name)

    intervention_info_copy = JSON.parse JSON.stringify intervention_info
    parameter_values = await get_intervention_parameters(intervention_info.name)
    for i in [0 til intervention_info_copy.parameters.length]
      parameter = intervention_info_copy.parameters[i]
      parameter.value = parameter_values[parameter.name]
      intervention_info_copy.params[parameter.name].value = parameter_values[parameter.name]

    if cached_systemjs_code != null
      systemjs_content_script_code = cached_systemjs_code
    else
      systemjs_content_script_code = await localget('/intervention_utils/systemjs.js')
      cached_systemjs_code := systemjs_content_script_code

    debug_content_script_code = """
    content_script_debug.listen_for_eval(function(command_to_evaluate) {
      if (window.customeval) {
        return window.customeval(command_to_evaluate);
      } else if (window.debugeval) {
        return window.debugeval(command_to_evaluate);
      } else {
        return window.eval(command_to_evaluate);
        //return eval.bind(this)(command_to_evaluate);
      }
    });
    """
    if intervention_info_copy.params.debug? and intervention_info_copy.params.debug.value
      debug_content_script_code = """
      content_script_debug.listen_for_eval((x) => { return eval(x); });
      content_script_debug.insert_console((x) => { return eval(x); }, {lang: 'livescript'});
      """
    debug_content_script_code_with_hlog = """
    SystemJS.import_multi(['prettyprintjs', 'libs_frontend/content_script_debug'], function(prettyprintjs, content_script_debug) {
      var console_log_orig = window.console.log;
      var hlog = function(...args) {
        console_log_orig(...args);
        var data_string;
        var err_to_throw = null;
        try {
          if (args.length == 1) {
            data_string = prettyprintjs(args[0]);
          } else {
            data_string = prettyprintjs(args);
          }
        } catch (err) {
          data_string = 'Error was thrown. Check Javascript console (Command+Option+J or Ctrl+Shift+J)\\n' + err.message;
          err_to_throw = err;
        }
        chrome.runtime.sendMessage({type: 'send_to_debug_terminal', data: {tab: tab_id, text: data_string}});
        if (err_to_throw) {
          throw err_to_throw;
        }
      }
      var uselib = function(libname, callback) {
        if (typeof(callback) == 'function') {
          SystemJS.import(libname).then(callback);
        } else if (typeof(callback) == 'string') {
          SystemJS.import(libname).then(function(imported_lib) {
            window[callback] = imported_lib;
            hlog('imported as window.' + callback);
          }, function(err) {
            console.log(err.message);
            throw err;
          });
        } else if (typeof(libname) == 'string') {
          callback = libname.toLowerCase().split('').filter((x) => 'abcdefghijklmnopqrstuvwxyz0123456789'.indexOf(x) != -1).join('');
          SystemJS.import(libname).then(function(imported_lib) {
            window[callback] = imported_lib;
            hlog('imported as window.' + callback);
          }, function(err) {
            console.log(err.message);
            throw err;
          });
        } else {
          hlog([
            'Use uselib() to import jspm libraries.',
            'The first argument is the library name (under SystemJS, see jspm)',
            'The second argument is the name it should be given (in the \\'this\\' object)',
            'Example of using moment:',
            '    uselib(\\'moment\\', \\'moment\\')',
            '    window.moment().format()',
            'Example of using jquery:',
            '    uselib(\\'jquery\\', \\'$\\')',
            '    window.$(\\'body\\').css(\\'background-color\\', \\'black\\')',
            'Example of using sweetalert2:',
            '    uselib(\\'libs_common/content_script_utils\\', \\'content_script_utils\\')',
            '    content_script_utils.load_css_file(\\'bower_components/sweetalert2/dist/sweetalert2.css\\')',
            '    uselib(\\'sweetalert2\\', \\'swal\\')',
            '    swal(\\'hello world\\')'
          ].join('\\n'))
        }
      }
      window.hlog = hlog;
      window.uselib = uselib;
      window.localeval = function(command_to_evaluate) {
        return eval(command_to_evaluate);
      }
      #{debug_content_script_code}
      return;
    })
    """
    open_debug_page_if_needed = ''
    if localstorage_getbool('open_debug_console_on_load')
      open_debug_page_if_needed = """
      SystemJS.import('libs_frontend/intervention_debug_console').then(function(intervention_debug_console) {
        intervention_debug_console.open_debug_page()
      })
      """
    for options in content_script_options
      if options.code?
        content_script_code = options.code
      else
        content_script_code = await localget(options.path)
      if options.jspm_require
        content_script_code_prequel = """
        const intervention = #{JSON.stringify(intervention_info_copy)};
        const parameters = #{JSON.stringify(parameter_values)};
        const tab_id = #{tabId};
        const dlog = function(...args) { console.log(...args); };
        const set_default_parameters = function(parameter_object) {
          for (let parameter_name of Object.keys(parameter_object)) {
            if (parameters[parameter_name] == null) {
              parameters[parameter_name] = parameter_object[parameter_name];
            }
          }
        };

        """
        content_script_code = """
        window.Polymer = window.Polymer || {}
        window.Polymer.dom = 'shadow'
        SystemJS.import('libs_common/intervention_info').then(function(intervention_info_setter_lib) {
          intervention_info_setter_lib.set_intervention(#{JSON.stringify(intervention_info_copy)});
          intervention_info_setter_lib.set_tab_id(#{tabId});
          SystemJS.import('data:text/javascript;base64,#{btoa(unescape(encodeURIComponent(content_script_code_prequel + content_script_code)))}');
        })
        """
        /*
        SystemJS.import('libs_common/intervention_info').then(function(intervention_info_setter_lib) {
          intervention_info_setter_lib.set_intervention(#{JSON.stringify(intervention_info_copy)})
          #{content_script_code}
        })
        */
        /*
        SystemJS.import('libs_common/intervention_info').then(function(intervention_info_setter_lib) {
          intervention_info_setter_lib.set_intervention(#{JSON.stringify(intervention_info_copy)});
          SystemJS.import('data:text/javascript;base64,#{btoa(content_script_code)}');
        })
        */
        /*
        SystemJS.import('libs_common/intervention_info').then(function(intervention_info_setter_lib) {
          intervention_info_setter_lib.set_intervention(#{JSON.stringify(intervention_info_copy)})
          SystemJS.import('libs_common/systemjs_require').then(function(systemjs_require) {
            systemjs_require.make_require(#{JSON.stringify(options.jspm_deps)}).then(function(require) {
              #{content_script_code}
            })
          })
        })
        */
      content_script_code = """
  if (!window.allowed_interventions) {
    window.allowed_interventions = #{JSON.stringify(as_dictset(intervention_list))};

    window.onunhandledrejection = function(evt) {
      throw evt.reason;
    };

    window.loaded_interventions = {};
    window.loaded_content_scripts = {};
  }

  if (window.allowed_interventions['#{intervention_info_copy.name}'] && !window.loaded_interventions['#{intervention_info_copy.name}']) {
    window.loaded_interventions['#{intervention_info_copy.name}'] = true;

    if (!window.loaded_content_scripts['#{options.path}']) {
      window.loaded_content_scripts['#{options.path}'] = true;
      const intervention = #{JSON.stringify(intervention_info_copy)};
      const parameters = #{JSON.stringify(parameter_values)};
      const tab_id = #{tabId};
      const dlog = function(...args) { console.log(...args); };
      const set_default_parameters = function(parameter_object) {
        for (let parameter_name of Object.keys(parameter_object)) {
          if (parameters[parameter_name] == null) {
            parameters[parameter_name] = parameter_object[parameter_name];
          }
        }
      };
      window.intervention_disabled = false;

      if (!window.SystemJS) {
        #{systemjs_content_script_code}
      }
      #{content_script_code}
      #{debug_content_script_code_with_hlog}
      SystemJS.import_multi(['libs_common/intervention_info', 'libs_frontend/intervention_log_utils'], function(intervention_info_setter_lib, log_utils) {
        intervention_info_setter_lib.set_intervention(intervention);
        intervention_info_setter_lib.set_tab_id(tab_id);
        log_utils.log_impression();
        document.body.addEventListener('disable_intervention', function() {
          window.intervention_disabled = true;
          log_utils.log_disable();
          if (typeof(window.on_intervention_disabled) == 'function') {
            window.on_intervention_disabled();
          } else {
            SystemJS.import_multi(['libs_frontend/content_script_utils', 'sweetalert2'], function(content_script_utils, sweetalert) {
              content_script_utils.load_css_file('sweetalert2').then(function() {
                sweetalert({
                  title: 'Reload page to turn off intervention',
                  text: 'This intervention has not implemented support for disabling itself. Reload the page to disable it.'
                })
              })
            })
          }
        })
        #{open_debug_page_if_needed}
      })
    }
  }
      """
      await yfy(chrome.tabs.executeScript) tabId, {code: content_script_code, allFrames: options.all_frames, runAt: options.run_at}
    return

  load_intervention_list = (intervention_list, tabId) ->>
    if intervention_list.length == 0
      return

    all_interventions = await get_interventions()
    intervention_info_list = [all_interventions[intervention_name] for intervention_name in intervention_list]

    # load background scripts
    for intervention_info in intervention_info_list
      for options in intervention_info.background_script_options
        await load_background_script options, intervention_info

    # load css files
    chrome.tabs.insertCSS tabId, {code: '''
@font-face {
  font-family: 'Open Sans';
  font-style: normal;
  font-weight: 400;
  src: url(data:application/x-font-woff;charset=utf-8;base64,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) format('woff2');
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02C6, U+02DA, U+02DC, U+2000-206F, U+2074, U+20AC, U+2212, U+2215;
}
    '''}

    for intervention_info in intervention_info_list
      if intervention_info.css_files?
        for css_file in intervention_info.css_files
          await new Promise -> chrome.tabs.insertCSS tabId, {file: css_file}, it
      if intervention_info.styles?
        for css_code in intervention_info.styles
          await new Promise -> chrome.tabs.insertCSS tabId, {code: css_code}, it

    # load content scripts
    for intervention_info in intervention_info_list
      await execute_content_scripts_for_intervention intervention_info, tabId, intervention_list
    return

  load_intervention = (intervention_name, tabId) ->>
    await load_intervention_list [intervention_name], tabId

  list_loaded_interventions = ->>
    await send_message_to_active_tab 'list_loaded_interventions', {}

  get_session_id_for_tab_id_and_domain = (tabId, domain) ->>
    if not tab_id_to_domain_to_session_id[tabId]?
      tab_id_to_domain_to_session_id[tabId] = {}
    session_id = tab_id_to_domain_to_session_id[tabId][domain]
    if session_id?
      return session_id
    session_id = await get_new_session_id_for_domain(domain)
    tab_id_to_domain_to_session_id[tabId][domain] = session_id
    return session_id

  tab_id_to_loaded_interventions = {}

  domain_to_prev_enabled_interventions = {}

  page_was_just_refreshed = false

  load_intervention_for_location = promise-debounce (location, tabId) ->>
    if is_it_outside_work_hours()
      return
    if !is_habitlab_enabled_sync()
      return

    domain = url_to_domain(location)
    if not domain_to_prev_enabled_interventions[domain]?
      domain_to_prev_enabled_interventions[domain] = []
    prev_enabled_interventions = domain_to_prev_enabled_interventions[domain]
    all_enabled_interventions = await list_all_enabled_interventions_for_location(domain)
    domain_to_prev_enabled_interventions[domain] = all_enabled_interventions
    enabled_intervention_set_changed = JSON.stringify(all_enabled_interventions) != JSON.stringify(prev_enabled_interventions)
    session_id = await get_session_id_for_tab_id_and_domain(tabId, domain)
    active_interventions = await getkey_dictdict 'interventions_active_for_domain_and_session', domain, session_id
    dlog 'active_interventions is'
    dlog active_interventions
    override_enabled_interventions = localStorage.getItem('override_enabled_interventions_once')
    dlog 'override_enabled_interventions is'
    dlog override_enabled_interventions
    if not active_interventions?
      if override_enabled_interventions?
        possible_interventions = as_array(JSON.parse(override_enabled_interventions))
      else
        possible_interventions = await list_enabled_nonconflicting_interventions_for_location(domain)
      intervention = possible_interventions[Math.floor(Math.random() * possible_interventions.length)]
      if intervention?
        await set_active_interventions_for_domain_and_session domain, session_id, [intervention]
      else
        await set_active_interventions_for_domain_and_session domain, session_id, []
      localStorage.removeItem('override_enabled_interventions_once')
    else
      active_interventions = JSON.parse active_interventions
      intervention = active_interventions[Math.floor(Math.random() * active_interventions.length)]
      intervention_no_longer_enabled = false
      need_new_session_id = false
      #if page_was_just_refreshed
      #  need_new_session_id = true
      if intervention?
        intervention_no_longer_enabled = all_enabled_interventions.length > 0 and all_enabled_interventions.indexOf(intervention) == -1
        if intervention_no_longer_enabled
          need_new_session_id = true
      #else
      #  if enabled_intervention_set_changed
      #    need_new_session_id = true
      if enabled_intervention_set_changed
        need_new_session_id = true
      if need_new_session_id
        # the intervention is no longer enabled. need to choose a new session id
        dlog 'intervention is no longer enabled. choosing new session id'
        dlog 'tabid is ' + tabId
        dlog 'domain is ' + domain
        dlog 'old session_id is ' + session_id
        dlog 'active_interventions'
        dlog active_interventions
        dlog 'all_enabled_interventions'
        dlog all_enabled_interventions
        session_id = await get_new_session_id_for_domain(domain)
        tab_id_to_domain_to_session_id[tabId][domain] = session_id
        if override_enabled_interventions?
          possible_interventions = as_array(JSON.parse(override_enabled_interventions))
        else
          possible_interventions = await list_enabled_nonconflicting_interventions_for_location(location)
        intervention = possible_interventions[0]
        #domain_to_session_id_to_intervention[domain][session_id] = intervention
        if intervention?
          await set_active_interventions_for_domain_and_session domain, session_id, [intervention]
        else
          await set_active_interventions_for_domain_and_session domain, session_id, []
        localStorage.removeItem('override_enabled_interventions_once')
    page_was_just_refreshed := false
    interventions_to_load = []
    if intervention?
      interventions_to_load.push intervention
    #if not intervention?
    #  return
    #await load_intervention intervention, tabId
    if not override_enabled_interventions?
      permanently_enabled_interventions = localStorage.getItem('permanently_enabled_interventions')
      if permanently_enabled_interventions?
        permanently_enabled_interventions = as_array(JSON.parse(permanently_enabled_interventions))
        all_available_interventions = await list_available_interventions_for_location(location)
        all_available_interventions = as_dictset(all_available_interventions)
        permanently_enabled_interventions = permanently_enabled_interventions.filter (x) -> all_available_interventions[x]
        for permanently_enabled_intervention in permanently_enabled_interventions
          if permanently_enabled_intervention != intervention
            interventions_to_load.push permanently_enabled_intervention
            #await load_intervention permanently_enabled_intervention, tabId
    tab_id_to_loaded_interventions[tabId] = interventions_to_load
    await load_intervention_list interventions_to_load, tabId
    return

  /*
  load_intervention_for_location = (location, tabId) ->>
    {work_hours_only ? 'false', start_mins_since_midnight ? '0', end_mins_since_midnight ? '1440'} = localStorage
    work_hours_only = work_hours_only == 'true'
    start_mins_since_midnight = parseInt start_mins_since_midnight
    end_mins_since_midnight = parseInt end_mins_since_midnight
    mins_since_midnight = moment().hours()*60 + moment().minutes()
    if work_hours_only and not (start_mins_since_midnight <= mins_since_midnight <= end_mins_since_midnight)
      return
    possible_interventions = await list_enabled_nonconflicting_interventions_for_location(location)
    for intervention in possible_interventions
      await load_intervention intervention, tabId
    localStorage.removeItem('override_enabled_interventions_once')
    return
  */

  getLocation = ->>
    #send_message_to_active_tab 'getLocation', {}, callback
    tabinfo = await get_active_tab_info()
    return tabinfo.url

  split_list_by_length = (list, len) ->
    output = []
    curlist = []
    for x in list
      curlist.push x
      if curlist.length == len
        output.push curlist
        curlist = []
    if curlist.length > 0
      output.push curlist
    return output

  css_packages = require('libs_common/css_packages')

  message_handlers = get_all_message_handlers()

  message_handlers <<< {
    'getLocation': (data) ->>
      location = await getLocation()
      #dlog 'getLocation background page:'
      #dlog location
      return location
    'load_intervention': (data) ->>
      {intervention_name, tabId} = data
      await load_intervention intervention_name, tabId
      return
    'load_intervention_for_location': (data) ->>
      {location, tabId} = data
      await load_intervention_for_location location, tabId
      return
    'load_css_file': (data) ->>
      {css_file, tab} = data
      tabid = tab.id
      if css_packages[css_file]?
        css_file = css_packages[css_file]
      #chrome.tabs.insertCSS tabid, {file: css_file}, ->
      #  callback()
      if css_file.startsWith('http://') or css_file.startsWith('https://')
        css_code = await remoteget(css_file)
        await new Promise -> chrome.tabs.insertCSS tabid, {code: css_code}, it
        return
      else
        css_code = await localget(css_file)
        await new Promise -> chrome.tabs.insertCSS tabid, {code: css_code}, it
        return
    'load_css_code': (data) ->>
      {css_code, tab} = data
      tabid = tab.id
      await new Promise -> chrome.tabs.insertCSS tabid, {code: css_code}, it
      return
    'send_to_debug_terminal': (data) ->>
      existing_messages = localstorage_getjson('debug_terminal_messages')
      if not existing_messages?
        existing_messages = []
      existing_messages.push data
      localstorage_setjson('debug_terminal_messages', existing_messages)
      return
  }

  #tabid_to_current_location = {}

  #which_interventions_are_loaded = (tabId, callback) ->

  prev_domain = ''

  domain_changed = (new_domain) ->
    prev_domain := new_domain
    current_day = get_days_since_epoch()
    addtokey_dictdict 'visits_to_domain_per_day', new_domain, current_day, 1, (total_visits) ->
      return
      #dlog "total visits to #{new_domain} today is #{total_visits}"

  # our definition of a session:
  # how long a tab was open and on Facebook (or other site of interest) until it was closed
  # some pitfalls. if user navigates to FB, then goes to say buzzfeed, then goes back (on that same tab) the sessions are merged
  tab_id_to_domain_to_session_id = {}
  # domain_to_session_id_to_intervention = {}
  tab_id_to_url = {}

  export list_domain_to_session_ids = ->
    for tab_id,domain_to_session_id of tab_id_to_domain_to_session_id
      dlog domain_to_session_id

  navigation_occurred = (url, tabId) ->
    new_domain = url_to_domain(url)
    if new_domain != prev_domain
      domain_changed(new_domain)
    #if tabid_to_current_location[tabId] == url
    #  return
    #tabid_to_current_location[tabId] = url
    #possible_interventions <- list_available_interventions_for_location(url)
    #if possible_interventions.length > 0
    #  chrome.pageAction.show(tabId)
    #else
    #  chrome.pageAction.hide(tabId)
    #send_pageupdate_to_tab(tabId)
    #dlog "navigation_occurred to #{url}"
    load_intervention_for_location url, tabId

  chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
    if changeInfo.status == 'loading' and not changeInfo.url?
      # user refreshed the page
      page_was_just_refreshed := true
    if tab.url
      tab_id_to_url[tabId] = tab.url
      #dlog 'tabs updated!'
      #dlog tab.url
      #if changeInfo.status != 'complete'
      #  return
      #if changeInfo.status == 'complete'
      #  send_message_to_tabid tabId, 'navigation_occurred', {
      #    url: tab.url
      #    tabId: tabId
      #  }
      if changeInfo.status == 'loading'
        add_tab_navigation_event tabId, tab.url

      send_message_to_tabid tabId, 'navigation_occurred', {
        url: tab.url
        tabId: tabId
      }
      navigation_occurred tab.url, tabId

      loaded_interventions = tab_id_to_loaded_interventions[tabId]
      if is_habitlab_enabled_sync()
        if loaded_interventions? and loaded_interventions.length > 0
          chrome.browserAction.setIcon {tabId: tabId, path: chrome.extension.getURL('icons/icon_active.svg')}
        else
          chrome.browserAction.setIcon {tabId: tabId, path: chrome.extension.getURL('icons/icon.svg')}
      else
        chrome.browserAction.setIcon {tabId: tabId, path: chrome.extension.getURL('icons/icon_disabled.svg')}

  reward_display_base_code_cached = null

  chrome.tabs.onRemoved.addListener (tabId, info) ->>
    url = tab_id_to_url[tabId]
    if not url?
      return
    domain = url_to_domain(url)
    session_id = tab_id_to_domain_to_session_id[tabId][domain]
    if not session_id?
      return
    interventions_active = await getkey_dictdict('interventions_active_for_domain_and_session', domain, session_id)
    if (not interventions_active?) or (interventions_active.length == 0) or interventions_active == '[]'
      return
    if reward_display_base_code_cached == null
      reward_display_base_code_cached := await fetch('frontend_utils/close_tab_message.js').then (.text!)
    baseline_seconds_spent = await baseline_time_per_session_for_domain(domain)
    seconds_spent = await getkey_dictdict('seconds_on_domain_per_session', domain, session_id)
    if seconds_spent > baseline_seconds_spent
      return
    seconds_saved = baseline_seconds_spent - seconds_spent
    current_tab_info = await get_active_tab_info()
    if (not current_tab_info?) or (not current_tab_info.url?)
      return
    if not (current_tab_info.url.startsWith('http://') or current_tab_info.url.startsWith('https://'))
      return
    reward_display_code = "window.reward_display_seconds_saved = " + seconds_saved + ";\n\n" + reward_display_base_code_cached
    chrome.tabs.executeScript current_tab_info.id, {code: reward_display_code}

  /*
  setInterval ->>
    base_code = await fetch('frontend_utils/close_tab_message.js').then (.text!)
    reward_display_code = "window.reward_display_seconds_saved = 6;\n\n" + base_code
    current_tab_info = await get_active_tab_info()
    chrome.tabs.executeScript current_tab_info.id, {code: reward_display_code}
  , 5000
  */

  #chrome.tabs.onActivated.addListener (info) ->
  #  console.log 'tab activated'
  #  console.log info

  chrome.webNavigation.onHistoryStateUpdated.addListener (info) ->
    #if info.tabId? and info.url?
    #  tab_id_to_url[info.tabId] = info.url
    send_message_to_tabid info.tabId, 'navigation_occurred', {
      url: info.url
      tabId: info.tabId
    }
    navigation_occurred info.url, info.tabId

  message_handlers_requiring_tab = {
    'load_css_file': true
    'load_css_code': true
  }

  chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    {type, data} = request
    #dlog 'onmessage'
    #dlog type
    #dlog data
    #dlog sender
    message_handler = message_handlers[type]
    if not message_handler?
      return
    # tabId = sender.tab.id
    if message_handlers_requiring_tab[type]
      if typeof(data) == 'object' and data != null and sender.tab? and not data.tab?
        data = {} <<< data
        data.tab = sender.tab
    message_handler(data).then (response) ->
      #dlog 'message handler response:'
      #dlog response
      #response_data = {response}
      #dlog response_data
      # chrome bug - doesn't seem to actually send the response back....
      #sendResponse response_data
      if sendResponse?
        sendResponse response
      # {requestId} = request
      # if requestId? # response requested
      #  chrome.tabs.sendMessage tabId, {event: 'backgroundresponse', requestId, response}
    if sendResponse?
      return true
    else
      return false

  #browser_focus_changed = (new_focused) ->
  #  dlog "browser focus changed: #{new_focused}"

  current_idlestate = 'active'

  # not supported by firefox
  chrome.idle?onStateChanged?addListener? (idlestate) ->
    current_idlestate := idlestate
    dlog "idle state changed: #{idlestate}"

  prev_browser_focused = false
  setInterval ->
    chrome.windows.getCurrent (browser) ->
      focused = browser.focused
      if focused != prev_browser_focused
        prev_browser_focused := focused
        #browser_focus_changed(focused)
  , 500

  /*
  export list_current_tab_ids = ->
    chrome.tabs.query {}, (tabs) ->
      output = {}
      for tab in tabs
        output[tab.url] = tab.id
      dlog output
  */

  setInterval (->>
    if !prev_browser_focused
      return
    if current_idlestate != 'active'
      return
    active_tab = await get_active_tab_info()
    if not active_tab?
      return
    if active_tab.url.startsWith('chrome://') or active_tab.url.startsWith('chrome-extension://') # ignore time spent on extension pages
      return
    current_domain = url_to_domain(active_tab.url)
    current_day = get_days_since_epoch()
    # dlog "currently browsing #{url_to_domain(active_tab.url)} on day #{get_days_since_epoch()}"
    session_id = await get_session_id_for_tab_id_and_domain(active_tab.id, current_domain)
    # dlog "session id #{session_id} current_domain #{current_domain} tab_id #{active_tab.id}"
    await addtokey_dictdict 'seconds_on_domain_per_session', current_domain, session_id, 1
    await addtokey_dictdict 'seconds_on_domain_per_day', current_domain, current_day, 1
    #addtokey_dictdict 'seconds_on_domain_per_day', current_domain, current_day, 1, (total_seconds) ->
    #  dlog "total seconds spent on #{current_domain} today is #{total_seconds}"
  ), 1000

  #localStorage.tabsOpened = 0
  #chrome.tabs.onCreated.addListener (x) ->
  #  localStorage.tabsOpened = Number(localStorage.tabsOpened) + 1

  /*
  setInterval (->>
    if !prev_browser_focused
      return
    if current_idlestate != 'active'
      return
    active_tab = await get_active_tab_info()
    if not active_tab?
      return
    if active_tab.url.startsWith('chrome://') or active_tab.url.startsWith('chrome-extension://') # ignore time spent on extension pages
      return
    current_domain = url_to_domain(active_tab.url)
    dlog "current domain is #{current_domain}"
    dlog "current tab id is #{active_tab.id}"
    session_id = await get_session_id_for_tab_id_and_domain(active_tab.id, current_domain)
    dlog "session_id: #{session_id}"
    seconds_spent = await get_seconds_spent_on_domain_in_session(current_domain, session_id)
    dlog "seconds spent: #{seconds_spent}"
  ), 1000
  */

  start_syncing_all_data()

  gexport_module 'background', -> eval(it)

  # systemjs_require <- SystemJS.import('libs_common/systemjs_require').then()
  # drequire <- systemjs_require.make_require_frontend().then()
  # window.require = drequire
  window.uselib = (libname, callback) ->
    if typeof(callback) == 'function'
      SystemJS.import(libname).then(callback)
    else if typeof(callback) == 'string'
      SystemJS.import(libname).then (imported_lib) ->
        window[callback] = imported_lib
        console.log('imported as window.' + callback)
    else if typeof(libname) == 'string'
      callback = libname.toLowerCase().split('').filter((x) -> 'abcdefghijklmnopqrstuvwxyz0123456789'.indexOf(x) != -1).join('')
      SystemJS.import(libname).then (imported_lib) ->
        window[callback] = imported_lib
        console.log('imported as window.' + callback)
    else
      console.log([
        'Use uselib() to import jspm libraries.'
        'The first argument is the library name (under SystemJS, see jspm)'
        'The second argument is the name it should be given (in the \'window\' object)'
        'Example of using moment:'
        '    uselib(\'moment\', \'moment\')'
        '    window.moment().format()'
        'Example of using jquery:'
        '    uselib(\'jquery\', \'$\')'
        '    window.$(\'body\').css(\'background-color\', \'black\')'
        'Example of using sweetalert2:'
        '    uselib(\'libs_common/content_script_utils\', \'content_script_utils\')'
        '    content_script_utils.load_css_file(\'bower_components/sweetalert2/dist/sweetalert2.css\')'
        '    uselib(\'sweetalert2\', \'swal\')'
        '    swal(\'hello world\')'
      ].join('\n'))
      

  ensure_history_utils_data_cached()

  require('libs_backend/require_remote_utils')

  #require('libs_backend/message_after_tab_close')
  require('libs_backend/notification_timer') #lewin notification_timer code

  await get_goal_intervention_info() # ensure cached
  await get_goals()
  await get_enabled_goals()

  get_habitlab_uninstall_url = ->>
    base64_js = require('base64-js')
    msgpack_lite = require('msgpack-lite')
    compress_and_encode = (data) ->
      base64_js.fromByteArray(msgpack_lite.encode(data))
    uninstall_url_base = 'https://habitlab.github.io/bye#'
    uninstall_url = uninstall_url_base
    uninstall_url_data = {}
    uninstall_url_data.v = habitlab_version
    if chrome.runtime.id == 'obghclocpdgcekcognpkblghkedcpdgd'
      uninstall_url_data.r = 0 # stable
    else if chrome.runtime.id == 'bleifeoekkfhicamkpadfoclfhfmmina'
      uninstall_url_data.r = 1 # beta
      uninstall_url_base = 'https://habitlab.netlify.com/bye#'
    else if developer_mode
      uninstall_url_data.r = 2 # developer
      uninstall_url_base = 'https://habitlab.netlify.com/bye#'
    else
      uninstall_url_data.r = 3 # unknown release
      uninstall_url_data.ri = chrome.runtime.id
    set_uninstall_url_if_valid = ->
      uninstall_url_next = uninstall_url_base + compress_and_encode(uninstall_url_data)
      if uninstall_url_next.length <= 255
        uninstall_url := uninstall_url_next
        return true
      return false # had an error
    uninstall_url_data.u = await get_user_id()
    uninstall_url_data.l = if (localStorage.getItem('allow_logging') == 'true') then 1 else 0
    if not set_uninstall_url_if_valid()
      return uninstall_url
    list_enabled_goals_short = ->>
      output = []
      goals = await get_enabled_goals()
      all_goals = await get_goals()
      for k,v of goals
        if not v
          continue
        goal_info = all_goals[k]
        output.push goal_info.sitename_printable
      return output
    uninstall_url_data.g = await list_enabled_goals_short()
    if not set_uninstall_url_if_valid()
      return uninstall_url
    return uninstall_url
  
  decode_habitlab_uninstall_url_data = (url) ->>
    data = url.substr(url.indexOf('/bye#') + 5) # 'https://habitlab.github.io/bye#'.length
    base64_js = require('base64-js')
    msgpack_lite = require('msgpack-lite')
    decompress_and_decode = (str) ->
      msgpack_lite.decode(base64_js.toByteArray(str))
    return decompress_and_decode(data)

  set_habitlab_uninstall_url = ->>
    habitlab_uninstall_url = await get_habitlab_uninstall_url()
    chrome.runtime.setUninstallURL(habitlab_uninstall_url)
  
  export open_habitlab_uninstall_url = ->>
    uninstall_url = await get_habitlab_uninstall_url()
    chrome.tabs.create {url: uninstall_url}

  if (not developer_mode) # not developer mode
    await set_habitlab_uninstall_url()

  num_times_restart_failed_due_to_loaded_interventions = 0
  num_times_restart_failed_due_to_loaded_interventions_active = 0
  num_times_restart_failed_due_to_habitlab_tab_open = 0
  num_times_restart_failed_due_to_habitlab_tab_open_active = 0
  restart_failed_priority_to_counts = [
    0 # have habitlab tab open and active
    0 # have habitlab intervention running and active
    0 # have habitlab intervention open
    0 # have habitlab tab open
  ]

  record_restart_failed = (priority) !->
    restart_failed_priority_to_counts[priority] += 1
    #dlog restart_failed_priority_to_counts
    restart_habitlab = ->
      chrome.runtime.reload()
      chrome.runtime.restart()
    if (priority == 0) and (restart_failed_priority_to_counts[0] >= 5000)
      restart_habitlab()
    if (priority == 1) and (restart_failed_priority_to_counts[0] + restart_failed_priority_to_counts[1] >= 1000)
      restart_habitlab()
    if (priority == 2) and (restart_failed_priority_to_counts[0] + restart_failed_priority_to_counts[1] + restart_failed_priority_to_counts[2] >= 250)
      restart_habitlab()
    if (priority == 3) and (restart_failed_priority_to_counts[0] + restart_failed_priority_to_counts[1] + restart_failed_priority_to_counts[2] + restart_failed_priority_to_counts[3]) >= 50
      restart_habitlab()
  export try_to_restart_habitlab_now = !->>
    open_tabs = await new Promise -> chrome.tabs.query({}, it)
    active_tabs = open_tabs.filter (.active)
    for tab_info in active_tabs
      if tab_info.url? and tab_info.url.startsWith(chrome.extension.getURL(''))
        # have a habitlab tab open currently, active
        return record_restart_failed(0)
    tab_ids_with_no_interventions = {}
    for tab_info in active_tabs
      loaded_interventions = await list_currently_loaded_interventions_for_tabid(tab_info.id)
      if loaded_interventions.length > 0
        # have loaded interventions, active
        return record_restart_failed(1)
      else
        tab_ids_with_no_interventions[tab_info.id] = true
    for tab_info in open_tabs
      if tab_ids_with_no_interventions[tab_info.id]?
        continue
      loaded_interventions = await list_currently_loaded_interventions_for_tabid(tab_info.id)
      if loaded_interventions.length > 0
        # have loaded interventions, not active
        return record_restart_failed(2)
    for tab_info in open_tabs
      if tab_info.url? and tab_info.url.startsWith(chrome.extension.getURL(''))
        # have a habitlab tab open currently, not active
        return record_restart_failed(3)
    chrome.runtime.reload()
    chrome.runtime.restart()

  habitlab_restarter_running = false
  export start_trying_to_restart_habitlab = !->>
    if habitlab_restarter_running
      return
    habitlab_restarter_running := true
    while true
      await try_to_restart_habitlab_now()
      await sleep(60000) # every 60 seconds

  require! {
    semver
  }

  {
    check_if_update_available_and_run_update
  } = require 'libs_backend/habitlab_update_utils'

  require 'libs_common/global_exports_post'

  update_available_version = localStorage.getItem('extension_update_available_version')
  if update_available_version?
    if not semver.valid(update_available_version)
      localStorage.removeItem('extension_update_available_version')
    if semver.gte(habitlab_version, update_available_version)
      localStorage.removeItem('extension_update_available_version')
  
  chrome.runtime.onUpdateAvailable.addListener (update_details) ->
    if semver.valid(update_details.version)
      localStorage.setItem('extension_update_available_version', update_details.version)
      start_trying_to_restart_habitlab()

  if (not developer_mode) and (localstorage_getbool('allow_logging'))
    run_every_timeperiod check_if_update_available_and_run_update, 600000 # 1000*60*10 every 10 minutes

  url_to_open_on_next_start = localStorage.getItem('habitlab_open_url_on_next_start')
  if url_to_open_on_next_start?
    localStorage.removeItem('habitlab_open_url_on_next_start')
    chrome.tabs.create {url: url_to_open_on_next_start}


