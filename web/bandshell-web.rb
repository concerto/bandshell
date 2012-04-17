# bandshell-web.rb
require 'sinatra'
require 'rubygems'
use Rack::Logger

#includes for system status functions
require 'sys/uptime'
require 'sys/proctable'
include Sys

#set global locations for config files (accessed with settings.{name})
set :instance_id_file, 'instance_id'
set :server_info_file, 'server_info'

configure :development do
  set :logging, Logger::DEBUG
end

get '/' do
  'Welcome to Bandshell!'
end

get '/screen' do
  if File.exists?(settings.instance_id_file)
    instance  = get_instance_id(settings.instance_id_file)
    #if instance is non-nil, direct user to instance
    if instance != ""
      redirect '/'
    else
      #send the user off to get a valid instance id
      redirect '/configure'     
    end
  else
    #the instance id file doesn't exist at all - send the user to get a valid instance id
    redirect '/configure'
  end
end

get '/configure' do
  if File.exists?(settings.server_info_file)
    server_info  = get_server_info(settings.server_info_file)
    
    #if the file is empty-send the user off to the server info form
    if server_info == ""
      erb :server_info_form
    else
      #read instance id from file
      if File.exists?(settings.server_info_file)
        instance = get_instance_id(settings.instance_id_file)
      end
      if instance != ""
        #download configuration info
        #redirect to player on server
      else
        #instance is nil; get temporary ID or request one from the server and save it
      end
    end
    
  #file doesn't exist - send the user off to the server info form  
  else
    erb :server_info_form
  end
end

#Accept a post request and read the server info into the globablly specified file
post '/configure' do
  set_server_info(settings.server_info_file,params[:server_address])
  redirect '/configure'
end

#Shows uptime,firmware version, and general system and process information
#Requires ffi, sys-uptime, and sys-proctable gems
get '/status' do
  @proctable = ProcTable.ps
  erb :player_status
end

get '/force_update' do
  #read instance id from file
  if File.exists?(settings.instance_id_file)
    instance = get_instance_id
  end
  #using the instance id, request the instance info from the webserver now
end