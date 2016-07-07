(() => {

if (window.block_after_interval_per_visit) {
  return
}
window.block_after_interval_per_visit = true

const $ = require('jquery')

require('enable-webcomponents-in-content-scripts')

//Polymer Component
require('bower_components/paper-slider/paper-slider.deps')
require('bower_components/paper-input/paper-input.deps')

//SkateJS Component
require('components_skate/time-spent-display')

require('components/interstitial-screen-polymer.deps')

const {
  log_impression,
  log_action,
} = require('libs_common/log_utils')

var timeLimitThisVisit;
var timeBegun;

//Adds a dialog that prompts user for the amount of time they would like to be on Facebook
function addBeginDialog(message) {
  //Adds dialog that covers entire screen
  const $whiteDiv = $('<div class="whiteOverlay">').css({
              'position': 'fixed',
              'top': '0%',
              'left': '0%',
              'width': '100%',
              'height': '100%',
              'background-color': '#f2fcff',
              'opacity': '0.97',
              'z-index': 350
  });
  $(document.body).append($whiteDiv)

  //Centered container for text in the white box
  const $contentContainer = $('<div class="contentContainer">').css({
              'position': 'absolute',
              'top': '50%',
              'left': '50%',
              'transform': 'translateX(-50%) translateY(-50%)'
  });

  const $timeText = $('<div class="titleText">').css({
    'font-size': '1.3em'
  });
  $timeText.html(message)
  $contentContainer.append($timeText)
  $contentContainer.append($('<p>'))

  const $slider = $('<paper-input label="minutes" auto-validate allowed-pattern="[0-9]" style="background-color: #94e6ff"></paper-input>')
  $contentContainer.append($slider)
  $contentContainer.append($('<p>'))

  const $okButton = $('<button>');
  $okButton.text("Restrict My Minutes!");
  $okButton.css({'cursor': 'pointer', 'padding': '5px'});
  $okButton.click(() => {
    var minutes = document.querySelector("paper-input").value
    if (minutes === "") {
      if ($('.wrongInputText').length === 0) {
        const $wrongInputText = $('<div class="wrongInputText">').css({
          'color': 'red'
        })
        $wrongInputText.html("You must input a number.")
        $wrongInputText.insertAfter($slider)          
      }
    } else {
      timeBegun = Math.floor(Date.now() / 1000)
      timeLimitThisVisit = minutes * 60

      $('.whiteOverlay').remove()
      displayCountdown()
    }
  })

  const $center = $('<center>')
  $center.append($okButton)
  $contentContainer.append($center);

  $whiteDiv.append($contentContainer)
}

function addEndDialog(message) {
  const $whiteDiv = $('<div class="whiteOverlay">').css({
              'position': 'fixed',
              'top': '0%',
              'left': '0%',
              'width': '100%',
              'height': '100%',
              'background-color': 'white',
              'z-index': 350
  });
  $(document.body).append($whiteDiv)

  //Centered container for text in the white box
  const $contentContainer = $('<div class="contentContainer">').css({
              'position': 'absolute',
              'top': '50%',
              'left': '50%',
              'transform': 'translateX(-50%) translateY(-50%)'
  });  
  const $timeText = $('<div class="titleText">').css({
    'font-size': '3em',
    'color': 'red'
  });
  $timeText.html(message)
  $contentContainer.append($timeText)
  $contentContainer.append($('<p>'))  

  $whiteDiv.append($contentContainer)  
}

//Retrieves the remaining time left for the user to spend on facebook
function getRemainingTimeThisVisit() {
  const timeSpent = Math.floor(Date.now() / 1000) - timeBegun 
  return timeLimitThisVisit - timeSpent
}

//Displays the countdown on the bottom left corner of the Facebook page
function displayCountdown() {
  const display_timespent_div = $('<div class="timeSpent" style="background-color: #3B5998; position: fixed; color: white; width: 150px; height: 50px; bottom: 0px; left: 0px; z-index: 99999">')
  $('body').append(display_timespent_div)

  const countdownTimer = setInterval(() => {
    const remainingTime = getRemainingTimeThisVisit()
    display_timespent_div.text("You have " + Math.floor(remainingTime/60) + " minute(s) and " + remainingTime%60 + " seconds left on Facebook")
    if (remainingTime < 0) {
      $('.timeSpent').remove()
      addEndDialog("Your time this visit is up!")
      clearInterval(countdownTimer)
    }  
  }, 1000);
}

function main() {
  addBeginDialog("How many minutes would you like to spend on Facebook this visit?")
}

main();

})()