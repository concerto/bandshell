#!/usr/bin/env ruby

require 'bandshell/config_store'

module Bandshell
  module Passwords
    def self.set_local_passwords
      #if the password has not been changed before during initial setup,
      #read a new one and change passwords accordingly
      unless Bandshell::ConfigStore.config_exists?('system_passwords_changed')
        system_password = Bandshell::ConfigStore.read_config('system_password', '')
        unless system_password.empty?
          IO.popen("chpasswd", mode='r+') do |io|
            io.write "root:#{system_password}"
            io.write "concerto:#{system_password}"
            result = io.read
            if result == 0
              Bandshell::ConfigStore.delete_config('system_password')
              Bandshell::ConfigStore.write_config('system_passwords_changed', 'true')
            end
            io.close_write
          end
        end
      end
    end
  end
end
