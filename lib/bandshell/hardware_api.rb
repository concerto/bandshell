require 'bandshell/config_store'
require 'net/http'
require 'json'

module Bandshell
  module HardwareApi
    class << self
    def temp_token
      Bandshell::ConfigStore.read_config('auth_temp_token')
    end

    def auth_token
      Bandshell::ConfigStore.read_config('auth_token')
    end

    def concerto_url
      Bandshell::ConfigStore.read_config('concerto_url', '')
    end

    def frontend_uri
      URI::join(concerto_url,'frontend')
    end

    def frontend_api_uri
      URI::join(concerto_url,'frontend.json')
    end
    
    def have_temp_token?
      !temp_token.empty?
    end

    def have_auth_token?
      !auth_token.empty?
    end

    attr_reader :screen_id, :screen_url

    def attempt_to_get_screen_data!
      unless have_temp_token? or have_auth_token?
        request_temp_token!
      end

      unless have_auth_token?
        check_temp_token!
      end

      if have_auth_token?
        status = fetch_screen_data
        if status == :stat_badauth
          ConfigStore.write_config('auth_token','')
          request_temp_token!
        end
      else
        status = :stat_err
      end
      status
    end

    private

    def clear_screen_data
      @status = nil
      @screen_url = nil
      @screen_id =nil
    end
      
    # Get array of data about the screen from the server
    # This can only succeed once we have obtained a valid auth token.
    def fetch_screen_data
      return nil if auth_token.empty?

      response = get_with_auth(frontend_api_uri, 'screen', auth_token)
      if response.nil?
        clear_screen_data
        return :stat_serverr
      end
        
      if response.code != "200"
        clear_screen_data
        return :stat_serverr
      end
      
      begin
        data = JSON.parse(response.body)
        if data.has_key? 'screen_id'
          @screend_id = data['screen_id']
          @screen_url = data['frontend_url']
          return :stat_success
        else
          clear_screen_data
          return :stat_badauth
        end
      rescue
        clear_screen_data
        return :stat_serverr
      end
    end


    def get_with_auth(uri, user, pass)
      begin
        req = Net::HTTP::Get.new(uri.to_s)
        req.basic_auth user, pass
        res = Net::HTTP.start(uri.hostname, uri.port) { |http|
          http.request(req)
        }
      rescue Errno::ECONNREFUSED
        res = nil
      end
      res
    end

    def request_temp_token!
      response = Net::HTTP.get_response(frontend_api_uri)
      if response.code != "200"
        return false
      end

      data=JSON.parse(response.body)
      if data.has_key? 'screen_temp_token'
        ConfigStore.write_config('auth_temp_token',data['screen_temp_token'])
        return true
      end
      return false
    end

    def check_temp_token!
      return false if temp_token.empty?

      query = URI.join(frontend_api_uri,"?screen_temp_token="+temp_token)
      response = Net::HTTP.get_response(query)
      if response.code != "200"
        return false
      end

      data=JSON.parse(response.body)
      if data.has_key? 'screen_auth_token'
        ConfigStore.write_config('auth_token',data['screen_auth_token'])
        ConfigStore.write_config('auth_temp_token','')
        return true
      end
      return false
    end
  end
  end # module HardwareApi
end # module Bandshell
