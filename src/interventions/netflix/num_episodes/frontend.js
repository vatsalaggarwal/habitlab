window.Polymer = window.Polymer || {}
window.Polymer.dom = 'shadow'

if (typeof(window.wrap) != 'function') {
  window.wrap = null;
}

require('enable-webcomponents-in-content-scripts')
require('components/num_episodes.deps')
const $ = require('jquery')

const {
  is_on_same_domain_and_same_tab
} = require('libs_common/session_utils')
