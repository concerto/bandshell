#!/usr/bin/env ruby
#Requires "daemons" gem

#Starts the Web App Server & verifies that it is still alive
#Starts the Browser & verifies that it is still alive
#Periodically uses local library methods to check for updates from the server
#Controls screen according to rules downloaded from server

#Start the daemon loop - everything happens in there
loop do
  sleep(5)
end
