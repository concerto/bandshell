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
      # Trailing slash required for proper URI Join behavior.
      # Double slashes not harmful.
      Bandshell::ConfigStore.read_config('concerto_url', '')+"/"
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

    # Can return:
    #   :stat_badauth
    #   :stat_err
    #   :stat_serverr on connection or sever failure
    #   :stat_badauth on an invalid permanent token
    #   :stat_success when screen data retrieved.
    def attempt_to_get_screen_data!
      unless have_temp_token? or have_auth_token?
        request_temp_token!
      end

      unless have_auth_token?
        tt_status = check_temp_token!
        return tt_status unless tt_status == :stat_success
      end

      if have_auth_token?
        status = fetch_screen_data
        if status == :stat_badauth
          ConfigStore.write_config('auth_token','')
          request_temp_token!
        end
      elsif have_temp_token?
        status = :stat_temponly
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
    
    def get_https_response(uri, options={})
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri.request_uri
        unless options[:user].nil?  && options[:pass].nil?
          request.basic_auth options[:user], options[:pass]
        end
        response = http.request request
      end
    end    
      
    # Get array of data about the screen from the server
    # This can only succeed once we have obtained a valid auth token.
    # Returns:
    #   :stat_serverr on connection or sever failure
    #   :stat_badauth on an invalid permanent token
    #   :stat_success when screen data retrieved.
    # TODO: save screen data in configs???
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
        response = get_https_response(uri, {:user => user, :pass => pass})         
      rescue StandardError => ex
        puts "get_with_auth: Failed to access concerto server:\n"+
             "   "+ex.message.chomp
        response = nil
      end
      response
    end

    def request_temp_token!
      begin
        response = get_https_response(frontend_api_uri)
        
        if response.code != "200"
          puts "request_temp_token: Unsuccessful request, HTTP "+response.code+"."
          return false
        end

        data=JSON.parse(response.body)
        if data.has_key? 'screen_temp_token'
          # We modify the token by appending an "s".
          # Concerto allows this and concerto-hardware will use it to
          # recognize that the user is setting up a managed player in
          # addition to a simple screen.
          token = data['screen_temp_token'] + 's'
          ConfigStore.write_config('auth_temp_token',token)
          return true
        end
        return false   
      rescue StandardError => ex
        puts "request_temp_token: Failed to access concerto server:\n"+
             "   "+ex.message.chomp
        return false
      end
    end

    # If the temp token has been accepted, convert it into an auth token,
    # which is saved in the config store.
    # Returns success of the action of checking:
    #   stat_err on generic or unknown errors
    #   stat_serverr if the server is inaccessible or erroring
    #   stat_success if the acceptedness was reliably determined
    def check_temp_token!
      return :stat_err if temp_token.empty? #should not happen

      query = URI.join(frontend_api_uri,"?screen_temp_token="+temp_token)
      begin   
        response = get_https_response(query)

        if response.code != "200"
          puts "check_temp_token: Unsuccessful request, HTTP "+response.code+"."
          return :stat_serverr
        end
        
        data=JSON.parse(response.body)
        if data.has_key? 'screen_auth_token'
          ConfigStore.write_config('auth_token',data['screen_auth_token'])
          ConfigStore.write_config('auth_temp_token','')
          return :stat_success
        elsif data.has_key? 'screen_temp_token'
          # Indicates the API was accessed successfuly but the temp token
          # has not been entered yet.
          return :stat_success
        end
        return :stat_err

      rescue StandardError => ex
        puts "check_temp_token: Failed to access concerto server:\n"+
             "   "+ex.message.chomp
        return :stat_serverr
      end     
    end

    public

    # Fetch player settings from concerto-hardware
    # TODO: clean up errors/ return values
    def get_player_info
      return nil if auth_token.empty?

      # Try to do this in one GET.
      player_info_uri = URI::join(concerto_url,'hardware/',
                                 'players/','current.json')

      response = get_with_auth(player_info_uri, 'screen', auth_token)
      if response.nil?
        return :stat_serverr
      end
        
      if response.code != "200"
        return :stat_serverr
      end
      
      begin
        data = JSON.parse(response.body)
        if data.has_key? 'screen_on_off'
          # We actually got some data
          return data
        else
          return :stat_badauth
        end
      rescue
        return :stat_serverr
      end
    end

    end # class << self
  end # module HardwareApi
end # module Bandshell
