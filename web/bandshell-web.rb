# bandshell-web.rb
require 'sinatra'
use Rack::Logger

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
    instance  = get_instance_id
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
    server_info  = get_server_info
    
    #if the file is empty-send the user off to the server info form
    if server_info == ""
      erb :server_info_form
    else
      #read instance id from file
      if File.exists?(settings.server_info_file)
        instance = get_instance_id
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
  File.open(settings.server_info_file, 'w') do |f|
    f.write params[:server_address]
  end
  redirect '/configure'
end

#Shows uptime,firmware version, and general system and process information
get '/status' do
  erb :player_status
end

get '/force_update' do
  #read instance id from file
  if File.exists?(settings.instance_id_file)
    instance = get_instance_id
  end
  #using the instance id, request the instance info from the webserver now
end

#return the contents of the instance id file and error if it's not found
def get_instance_id
  begin
    f = File.open(settings.instance_id_file,'r')
    instance  = f.read
    return instance
  rescue Errno::ENOENT
    puts "Instance file not found!"
  end
end

#return the contents of the server info file and error if it's not found
def get_server_info
  begin
    f = File.open(settings.server_info_file,'r')
    server_info  = f.read
    return server_info
  rescue Errno::ENOENT
    puts "Server info file not found!"
  end
end