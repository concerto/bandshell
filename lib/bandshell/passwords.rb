#!/usr/bin/env ruby

require 'bandshell/config_store'

module Bandshell
  module Passwords
    def set_local_passwords
      #if the password has not been changed before during initial setup,
      #read a new one and change passwords accordingly
      unless Bandshell::ConfigStore.config_exists?('system_passwords_changed')
        system_password = Bandshell::ConfigStore.read_config('system_password', '')
        unless system_password.empty?
          system("echo \"root:#{system_password}\" | chpasswd")
          system("echo \"concerto:#{system_password}\" | chpasswd")
          Bandshell::ConfigStore.delete_config('system_password')
          Bandshell::ConfigStore.write_config('system_passwords_changed', 'true')
        end
      end
    end
end
