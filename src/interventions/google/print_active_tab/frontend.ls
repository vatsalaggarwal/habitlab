console.log('frontend.ls before listen_for_eval')
console.log('frontend.ls after listen_for_eval')

foobar = ->
  'hello world'

if intervention.params.debug.value
  {
    listen_for_eval
    insert_console
  } = require 'libs_frontend/content_script_debug'
  listen_for_eval ((x) -> eval(x))
  insert_console ((x) -> eval(x)), {lang: 'livescript'}
