(() => {

  if (window.make_user_wait) {
    return
  }
  window.make_user_wait = true

  require('enable-webcomponents-in-content-scripts')
  require('components/interstitial-screen.deps')
  const $ = require('jquery')

  const {
    log_impression,
    log_action,
  } = require('libs_common/log_utils')

  var interst_screen = $('<interstitial-screen>')
  var buttonText = 'Click to continue to Facebook'
  interst_screen.attr('btn-txt', buttonText)

  var buttonText2 = 'Close Tab'
  interst_screen.attr('btn-txt2', buttonText2)


  interst_screen[0].hideButton();
  interst_screen.attr('intervention', intervention.name)
  log_impression('facebook/make_user_wait')

  var secondsLeft = intervention.params.seconds.value
  var countdown = setInterval(function() {
    var messageString = 'Facebook will be available in...' + secondsLeft;
    secondsLeft--
    interst_screen.attr('title-text', messageString)
    if (secondsLeft < 0) {
      clearInterval(countdown)
      interst_screen.attr('title-text', 'Facebook is available, if you really want to visit.')
      interst_screen[0].showButton();

    }
  }, 1000)

  $(document.body).append(interst_screen)



})()