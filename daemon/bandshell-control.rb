#Daemon control for the Bandshell daemon
#Usage: ruby myserver_control.rb start|stop|restart

require 'rubygems'
require 'daemons'

Daemons.run_proc('bandshell-daemon.rb') do
  loop do
    sleep(5)
  end
end