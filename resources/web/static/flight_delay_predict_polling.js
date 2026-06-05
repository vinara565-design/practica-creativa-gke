$(document).ready(function() {
  var socket = io();

  socket.on('connect', function() {
    console.log('Socket.IO connected!');
  });

  socket.on('prediction', function(data) {
    console.log('Prediction received:', data);
    renderPage(data);
  });

  $("#flight_delay_classification").submit(function(event) {
    event.preventDefault();
    var url = $(this).attr("action");
    $("#result").empty().append("Processing...");
    $.post(url, $("#flight_delay_classification").serialize()).done(function(data) {
      var response = JSON.parse(data);
      console.log("Request sent with id: " + response.id);
    });
  });
});

function renderPage(prediction) {
  var displayMessage;
  var p = prediction.Prediction;
  if(p == 0) displayMessage = "Early (15+ Minutes Early)";
  else if(p == 1) displayMessage = "Slightly Early (0-15 Minute Early)";
  else if(p == 2) displayMessage = "Slightly Late (0-30 Minute Delay)";
  else if(p == 3) displayMessage = "Very Late (30+ Minutes Late)";
  else displayMessage = "Unknown";
  $("#result").empty().append(displayMessage);
}