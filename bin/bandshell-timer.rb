# bandshell-timer.rb
# Periodically ping the bandshell web app so that background tasks
# may be performed. Called by bandshelld as a daemon.
require "net/http"

#TODO: Take bandshell URL/port as an argument from bandshelld
#BandshellURL= "http://localhost:"+ConcertoConfigServer.settings.port.to_s
BandshellURL= "http://localhost:"+4567.to_s
StatusURI = URI.parse(BandshellURL+"/background-job")
  
loop do
  sleep(5)
  begin
    response = Net::HTTP.get_response(StatusURI)
  rescue Errno::ECONNREFUSED
    puts "Bandshell is not responding."
  end
end
