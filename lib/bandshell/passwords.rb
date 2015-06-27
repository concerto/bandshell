#!/usr/bin/env ruby

require 'bandshell/config_store'

module Bandshell
  module Passwords
    def self.set_local_passwords
      if Bandshell::ConfigStore.config_exists?('system_passwords_changed')
        # if we have changed the passwords, try to restore the shadow file
        # from the configuration store
        restore_shadow
      else
        #if the password has not been changed before during initial setup,
        #read a new one and change passwords accordingly
        system_password = Bandshell::ConfigStore.read_config('system_password', '')
        unless system_password.empty?
          IO.popen("chpasswd", mode='r+') do |io|
            io.puts "root:#{system_password}"
            io.puts "concerto:#{system_password}"
          end

          if $? == 0 
            # remove plain text passwords from config and set flag
            Bandshell::ConfigStore.delete_config('system_password')
            Bandshell::ConfigStore.write_config('system_passwords_changed', 'true')

            # save shadow file (with password hashes) into config
            save_shadow
          else
            # chpasswd returned nonzero status... do something to indicate error
          end
        end
      end
    end
    
    def self.save_shadow
      shadow_content = IO.read("/etc/shadow")
      Bandshell::ConfigStore.write_config('shadow_file', shadow_content)
    end

    def self.restore_shadow
      oldshadow = IO.read("/etc/shadow")
      shadow_content = Bandshell::ConfigStore.read_config('shadow_file', oldshadow)
      IO.write("/etc/shadow", shadow_content)
    end
  end
end
