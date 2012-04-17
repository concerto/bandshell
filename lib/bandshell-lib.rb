#Bandshell Library Methods

#Set server address / get server information
#Request Temporary ID
#Request Real ID (based on a Temporary ID we already have)
#Check Configuration (based on our Real Instance ID)
#Get Status
#Force Reboot

#force reboot
def force_system_reboot
  system("reboot")
end

#write given server info to given filename
def set_server_info(filename,server_info)
  File.open(filename, 'w') do |f|
    f.write server_info
  end
end

#return the contents of the instance id file and error if it's not found
def get_instance_id(filename)
  begin
    f = File.open(filename,'r')
    instance  = f.read
    return instance
  rescue Errno::ENOENT
    puts "Instance file not found!"
  end
end

#return the contents of the server info file and error if it's not found
def get_server_info(filename)
  begin
    f = File.open(filename,'r')
    server_info  = f.read
    return server_info
  rescue Errno::ENOENT
    puts "Server info file not found!"
  end
end
