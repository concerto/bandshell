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
            io.puts "root:#{system_password}"
            io.puts "concerto:#{system_password}"
            io.close_write
            result = io.read
            if result
              Bandshell::ConfigStore.delete_config('system_password')
              Bandshell::ConfigStore.write_config('system_passwords_changed', 'true')
            end
          end
        end
      end
    end
  end
end
