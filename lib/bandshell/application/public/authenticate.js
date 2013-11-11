/* Concerto Authentication Javascript
 * Handles authenticating the player browser to Concerto and sending it
 * to the frontend.
 *
 * Basic workflow:
 *  - If the screen does not yet have a valid token:
 *     + displays the temporary token
 *     + polls the local server until the local server has a permanent token
 *     + continues to the next section:
 *  - If the screen has a valid token:
 *     + requests the relevant data from the local server
 *     + performs a one-time authenticated request to concerto to get
 *       an authentication cookie for the browser
 *     + redirects to the frontend
 * TODO: Error handling for failed requests / unexpected data
 * TODO: remove console.log statements
 */

var checkIntHandle; // Handle for the polling event

function update_status(statstring) {
    var stat=document.getElementById("status");
    stat.innerHTML=statstring;
}

// true unless there was an error
function check_token() {
  // make a request to localhost to see if we are ready to redirect
  var req = new XMLHttpRequest();
  req.addEventListener("load", function() {
    if (req.status != 200) {
      update_status("Error!"+req.readyState+"-"+req.status+req.statusText);
    } else {
      // window.clearInterval(checkIntHandle); //debug only
      update_status("");
      data=JSON.parse(this.responseText);
        console.log(data);
      if (data.accepted==1) {
        update_status("Success!");
        redirect_with_auth(data.url, data.user, data.pass);
      } else {
        update_status("");
      }
    }
  });
  req.addEventListener("error", function() {
    update_status("Error!");
  });
  req.open("GET", "authenticate.json", true);
  req.send();
}

function redirect_with_auth(url,user,pass) {
  var req = new XMLHttpRequest();
  auth_url = url + "?request_cookie";
  // Note: Firefox will prevent creating the request object for
  // cross-site requests if user and pass are given to open
  req.open("GET", auth_url, true);
  req.setRequestHeader("Authorization", "Basic " + btoa(user+":"+pass))
  req.withCredentials = true; //Not sure if needed or matters
  req.addEventListener("load", function() {
    if (req.status == 200) {
      console.log("redir here.");
      document.location=url;
    } else {
      console.log("GET FaILED");
      update_status("Error authenticating. Please refresh this page.");
    }
  });
  req.addEventListener("error", function() {
      console.log("GET ErROR");
  });
  req.addEventListener("abort", function() {
      console.log("GET abort");
  });
  req.send();
  console.log("sent");
}

window.onload = function () {
  console.log("initializing");
  var nojs=document.getElementById("no-js");
  nojs.parentNode.removeChild(nojs);

  // perform the first request ASAP
  update_status("");
  check_token();

  // schedule polling in such a way that the user can see what's going on
  checkIntHandle = window.setInterval(function(){ 
    update_status("Updating...");
    setTimeout(function() {
      check_token()
    },500);
  }, 5000);
}
