# bandshell-web.rb
require 'sinatra'
use Rack::Logger

configure :development do
  set :logging, Logger::DEBUG
end

get '/' do
  erb :home
end

post '/' do
  server_address_file = "server.cfg"
  File.open(server_address_file, 'w') do |f|
    f.write params[:server_address]
  end
end
