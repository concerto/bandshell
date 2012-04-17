# myapp.rb
require 'sinatra'

configure :development do
  set :logging, Rack::Logger::DEBUG
end

get '/' do
  logger.info "Saying hello..."
  'Hello world!'
end
