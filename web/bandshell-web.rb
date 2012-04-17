# myapp.rb
require 'sinatra'
use Rack::Logger

configure :development do
  set :logging, Logger::DEBUG
end

get '/' do
  logger.info "Saying hello..."
  'Hello world!'
end
