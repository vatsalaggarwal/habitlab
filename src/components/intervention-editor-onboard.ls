{polymer_ext} = require 'libs_frontend/polymer_utils'
{list_custom_interventions} = require 'libs_backend/intervention_utils'

{
  list_all_goals
  get_goals
} = require 'libs_backend/goal_utils'

polymer_ext {
  is: 'intervention-editor-onboard'
  properties:{
    custom_intervention_list:{
      type:Array
    }
    templates_list:{
      type:Array
      value:['make_user_wait',"my_template"]
    }
  }
  refresh_custom_intervention_list: ->>
    this.custom_intervention_list=await list_custom_interventions()
  open_code_clicked: (evt)->
    this.open_code(evt.model.intervention_name)
  open_code: (intervention_name)->
    console.log 'open_code'
    # chrome.tabs.create url: chrome.extension.getURL('index.html?tag=intervention-editor')
  add_new_clicked: ->>
    self = this
    create_intervention_dialog = document.createElement('create-intervention-dialog')
    document.body.appendChild(create_intervention_dialog)
    all_goals=await get_goals()
    goals_list= await list_all_goals()
    create_intervention_dialog.goal_info_list = [all_goals[x] for x in goals_list]
    create_intervention_dialog.open_create_new_intervention_dialog()
    create_intervention_dialog.addEventListener 'display_new_intervention', (evt) ->
      localStorage.setItem('intervention_editor_new_intervention_info', JSON.stringify(evt.detail))
  preivew_intervention: ->
    console.log 'preview_intervention'
  ready: ->>
    self=this
    await self.refresh_custom_intervention_list()
}, {
  source: require 'libs_frontend/polymer_methods'
  methods: [
  ]
}