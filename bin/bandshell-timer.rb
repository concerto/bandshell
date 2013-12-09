# bandshell-timer.rb
# Usage: bandshell-timer.rb ConcertoURL
# Where ConcertoURL Looks like http://localhost:4567
#
# Periodically ping the bandshell web app so that background tasks
# may be performed. Called by bandshelld as a daemon.
require "net/http"

def linestamp
  "bandshell-timer.rb ("+Time.now.to_s+"): "
end

puts ""
puts linestamp + "Bandshell timer starting up."
BandshellURL = ARGV[0]

if BandshellURL.nil? or BandshellURL.empty?
  raise linestamp + "Parameter Bandshell URL is required."
end

puts linestamp + "connecting to bandshell at " + BandshellURL

StatusURI = URI.parse(BandshellURL+"/background-job")
  
loop do
  sleep(5)
  begin
    response = Net::HTTP.get_response(StatusURI)
  rescue Errno::ECONNREFUSED
    puts linestamp + "Bandshell is not responding."
  rescue SocketError
    puts linestamp + "Could not connect to given URL."
  end
end
