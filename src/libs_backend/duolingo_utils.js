const {
  getvar,
  setvar,
} = require('libs_backend/db_utils')

async function get_duolingo_username_uncached() {
  let duolingo_text = await fetch('https://www.duolingo.com/info', {credentials: 'include'}).then(x => x.text())
  let username_text_query = "'username': "
  let username_idx = duolingo_text.indexOf(username_text_query)
  if (username_idx == -1) {
    return ''
  }
  let duolingo_text_after_username = duolingo_text.substr(username_idx + username_text_query.length + 1)
  let username_end_idx = duolingo_text_after_username.indexOf("'")
  if (username_end_idx == -1) {
    return ''
  }
  return duolingo_text_after_username.substr(0, username_end_idx)
}

async function get_duolingo_username() {
  let cached_duolingo_username = await getvar('duolingo_username')
  if (cached_duolingo_username != null && cached_duolingo_username.length > 0) {
    return cached_duolingo_username
  }
  let duolingo_username = await get_duolingo_username_uncached()
  if (duolingo_username != null && duolingo_username.length > 0) {
    await setvar('duolingo_username', duolingo_username)
  }
  return duolingo_username
}

async function get_duolingo_info_for_user(username) {
  if (username == null || username.length == 0) {
    return {}
  }
  return await fetch('https://www.duolingo.com/users/' + username, {credentials: 'include'}).then(x => x.json())
}

async function get_duolingo_info() {
  let duolingo_username = await get_duolingo_username()
  return await get_duolingo_info_for_user(duolingo_username)
}

module.exports = {
  get_duolingo_username,
  get_duolingo_username_uncached,
  get_duolingo_info_for_user,
  get_duolingo_info,
}
