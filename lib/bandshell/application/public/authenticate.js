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
 */

var checkIntHandle; // Handle for the polling event
var verbose = false;

window.arrify = function(args) {
  return (args.length == 1) ? args[0] : Array.prototype.slice.call(args);
}

// usage: log('inside coolFunc',this,arguments);
// http://paulirish.com/2009/log-a-lightweight-wrapper-for-consolelog/
window.log = function(){
  if(this.console) console.log( arrify(arguments) );
};
window.error = function(){
  // we'll use warn for "errors" so we can clarify between
  // logistical problems and actual JS errors.
  if(this.console) console.warn( arrify(arguments) );
};
window.debug = function(){
  if(this.console && verbose) console.debug( arrify(arguments));
};

function update_status(statstring) {
    var stat=document.getElementById("status");
    stat.innerHTML=statstring;
}

function check_token() {
  // make a request to localhost to see if we are ready to redirect
  var req = new XMLHttpRequest();
  req.addEventListener("load", function() {
    if (req.status != 200) {
      update_status("Error! Something went wrong with Bandshell.");
      error("Recieved an unexpected response from Bandshell, "+
        "status = "+req.status+" ("+req.statusText+")");
    } else {
      update_status("");
      try {
        data = JSON.parse(this.responseText);
      } catch (e) {
        update_status("Error: Bad data from Bandshell.");
        error("There was a problem with the JSON response from Bandshell:\n"+
          "   "+e.toString()+"\n"+
          "The text in question was:\n"+
          "   "+this.responseText);
        return;
      }
      if (data.accepted==1) {
        update_status("Success!");
        log("Temporary token accepted by the server.");
        redirect_with_auth(data.url, data.user, data.pass);
      } else {
        update_status("");
        debug("Token request declined.");
      }
    }
  });
  req.addEventListener("error", function() {
    update_status("Error! Bandshell is not responding.");
    error("Request to Bandshell failed. "+
      "status = "+req.status+".");
  });
  req.open("GET", "authenticate.json", true);
  req.send();
}

/* Basic theory of operation:
 * We use a complicated CORs setup to login to the frontend with an XHR
 * request. Normally frontend API requests should be stateless, but if
 * we pass ?request_cookie the frontend will assign a cookie with the
 * screen token, under Concerto's domain, to the client browser (important
 * because redirecting with basic auth is flaky). Now when we redirect to
 * the frontend, the cookie is used and the screen is authenticated.
 */
function redirect_with_auth(url,user,pass) {
  log("Attempting pre-authorization for redirect to "+url+".");
  var req = new XMLHttpRequest();
  auth_url = url + "?request_cookie";
  // Note: Firefox will prevent creating the request object for
  // cross-site requests if user and pass are given to open
  req.open("GET", auth_url, true);
  req.setRequestHeader("Authorization", "Basic " + btoa(user+":"+pass))
  req.withCredentials = true;
  req.addEventListener("load", function() {
    if (req.status == 200) {
      log("Pre-authorization appears successful.");
      log("Redirecting to "+url+".");
      document.location=url;
    } else {
      update_status("Error authenticating. Please ensuring Concerto is "+
        "running properly.");
      error("Pre-authorization request resulted in status "+req.status+
        " from Concerto.");
    }
  });
  req.addEventListener("error", function() {
    update_status("Concerto Server Inaccessible. Make sure it is up.");
    error("Pre-authentication request to Concerto errored out.");
  });
  req.send();
}

window.onload = function () {
  log("Authentication Script Initializing");
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
