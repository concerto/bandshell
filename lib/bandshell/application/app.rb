require 'rubygems'
require 'sinatra/base'
require 'haml'
require 'json'
require 'net/http'
require 'ipaddress'
require 'bandshell/netconfig'
require 'sys/uptime'
require 'sys/proctable'
include Sys

class ConcertoConfigServer < Sinatra::Base
  # default to production, not development
  set :environment, (ENV['RACK_ENV'] || :production).to_sym

  # set paths relative to this file's location
  set :root, File.dirname(__FILE__)

  # listen on all IPv4 and IPv6 interfaces
  set :bind, '::'

  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  # push these over to netconfig.rb?
  # Our list of available physical-layer connection methods...
  CONNECTION_METHODS = [ 
    Bandshell::WiredConnection, 
    Bandshell::WirelessConnection 
  ]
  # ... and available layer-3 addressing methods.
  ADDRESSING_METHODS = [ 
    Bandshell::DHCPAddressing, 
    Bandshell::StaticAddressing 
  ]

  # Hosts we allow to access configuration without authenticating.
  LOCALHOSTS = [ 
    IPAddress.parse("127.0.0.1"),    # ipv4 
    IPAddress.parse("::ffff:127.0.0.1"),  # ipv6-mapped ipv4
    IPAddress.parse("::1")      # ipv6
  ]

  set :haml, { :format => :html5, :layout => :main }

  helpers do
    # Get the return value of the method on obj if obj supports the method.
    # Otherwise return the empty string.
    # This is useful in views where arguments may be of diverse types.
    def value_from(obj, method)
      if obj.respond_to? method
        obj.send method
      else
        ""
      end
    end

    # Enforce authentication on actions.
    # Calling from within an action will check authentication and return 
    # 401 if unauthorized.
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = \
          %(Basic realm="Concerto Configuration")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    # Check authorization credentials.
    # Currently configured to check if the REMOTE_ADDR is local and allow
    # everything if so. This permits someone at local console to configure
    # without the need for a password. Others must have the correct 
    # password to be considered authorized.
    def authorized?
      ip = IPAddress.parse(request.env['REMOTE_ADDR'])
      password = Bandshell::ConfigStore.read_config(
        'password', 'default'
      )
      if LOCALHOSTS.include? ip
        # allow all requests from localhost no questions asked
        true
      else
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && \
          @auth.credentials == ['root', password]
      end
    end

    # Get our base URL from wherever it may be stored.
    def concerto_url
      Bandshell::ConfigStore.read_config('concerto_url', '')
    end

    # Try to figure out what our current IPv4 address is
    # and return it as a string.
    def my_ip
      iface = Bandshell.configured_interface
      if iface
        iface.ip
      else
        "Network setup failed or bad configuration"
      end
    end

    # Check if we have something resembling a network connection.
    # This means we found a usable interface and it has an IPv4 address.
    def network_ok
      iface = Bandshell.configured_interface
      if iface
        if iface.ip != "0.0.0.0"
          true
        else
          false
        end
      else
        false
      end
    end

    # Check if we can retrieve a URL and get a 200 status code.
    def validate_url(url)
      begin
        # this will fail with Errno::something if server 
        # can't be reached
        response = Net::HTTP.get_response(URI(url))
        if response.code != "200"
          # also bomb out if we don't get an OK response
          # maybe demanding 200 is too strict here?
          fail
        end

        # if we get here we have a somewhat valid URL to go to
        true
      rescue
        # our request bombed out for some reason
        false
      end
    end
  end

  get '/' do
    if concerto_url == ''
      redirect '/setup'
    else
      redirect '/player_status'
    end
  end

  # The local fullscreen browser will go to /screen.
  # We should redirect to the screen URL if possible.
  # Otherwise, we need to go to the setup page to show useful information
  # and allow for local configuration if needed/wanted.
  get '/screen' do
    # if we don't have a URL go to setup
    # if we do, check it out
    if concerto_url == ''
      redirect '/setup'
    else
      # check if the concerto server is reachable, if so redirect there
      # if not redirect to a local error message screen
      if validate_url(concerto_url)
        redirect concerto_url
      else
        redirect '/problem'
      end
    end
  end

  # Present a form for entering the base URL.
  get '/setup' do
    protected!
    if network_ok
      # Everything's up and running, we just don't know what 
      # our URL should be.
      haml :setup
    else
      # The network settings are not sane, we don't have an IP.
      # Redirect the user to the network configuration page to 
      # take care of this.
      redirect '/netconfig'
    end
  end

  # Save the Concerto base URL.
  post '/setup' do
    protected!
    url = params[:url]
    if validate_url(url)
      # save to the configuration store
      Bandshell::ConfigStore.write_config('concerto_url', url)

      # root will now redirect to the proper concerto_url
      redirect '/screen'
    else
      # the URL was no good, back to setup!
      # error handling flash something something something
      redirect '/setup'
    end
  end

  # render a page indicating that the concerto_url is no good.
  # this page redirects to / every 5 seconds
  get '/problem' do
    haml :problem
  end

  get '/netconfig' do
    protected!

    # parse existing config file (if any)
    # if there isn't one, nil will suffice because our
    # value_from(...) helper will return the empty string if a method
    # is not implemented. This is also how we get away with just having
    # one instance each of the config classes that are currently selected.
    begin
      cm, am = Bandshell.read_network_config
    rescue Errno::ENOENT
      cm = nil
      am = nil
    end

    # view will grab what it can from our existing 
    # connection/addressing methods using value_from().
    haml :netsettings, :locals => { 
        :connection_method => cm, 
        :addressing_method => am 
      }
  end

  # Given the name of a class, pick a class out of a list of allowed classes.
  # This is used for parsing the form input for network configuration.
  def pick_class(name, list)
    list.find { |klass| klass.basename == name }
  end

  # Extract arguments from a set of form data that are intended to go to a
  # specific network configuration class. These fields have names of the form
  # 'ClassName/field_name'; this function returns a hash in the form 
  # { 'field_name' => 'value } containing the configuration arguments.
  def extract_class_args(params, target_class)
    result = { }
    params.each do |key, value|
      klass, arg = key.split('/', 2)
      if klass == target_class
        result[arg] = value
      end
    end

    result
  end

  # Set the arguments on an instance of a given configuration class.
  # This uses the safe_assign method that should be present in all 
  # configuration classes to determine which values are allowed to be passed
  # via form fields (i.e. which ones are subject to validation)
  def do_assign(params, instance)
    safe = instance.safe_assign

    params.each do |param, value|
      if safe.include? param.intern
        instance.send((param + '=').intern, value)
      end
    end
  end

  # Process the form fields and generate a JSON network configuration file.
  post '/netconfig' do
    protected!

    # First we find the connection-method and addressing-method classes.
    cmclass = pick_class(params[:connection_type], CONNECTION_METHODS)
    fail "Connection method not supported" if cmclass.nil?
    
    amclass = pick_class(params[:addressing_type], ADDRESSING_METHODS)
    fail "Addressing method not supported" if amclass.nil?

    # ... and create some instances of them.
    cm = cmclass.new
    am = amclass.new
    
    # Now given the names of the specific classes the user has chosen,
    # extract the corresponding form fields.
    cmargs = extract_class_args(params, cmclass.basename)
    amargs = extract_class_args(params, amclass.basename)

    # Set properties on each instance given the form values passed in.
    do_assign(cmargs, cm)
    do_assign(amargs, am)

    # Save the configuration file.
    Bandshell.write_network_config(cm, am)

    # Reload network configuration.
    STDERR.puts "Trying to bring down the interface"
    if Bandshell.configured_interface
      Bandshell.configured_interface.ifdown
    end
    STDERR.puts "Rewriting configuration files"
    Bandshell::configure_system_network
    STDERR.puts "Bringing interface back up"
    Bandshell.configured_interface.ifup

    # Back to the network form.
    redirect '/netconfig' # as a get request
  end

  get '/password' do
    protected!
    haml :password
  end

  post '/password' do
    protected!
    
    if params[:newpass] != params[:newpass_confirm]
      # something something error handling something
      redirect '/password'
    end
    
    Bandshell::ConfigStore.write_config('password', params[:newpass])
    redirect '/setup'
  end
  
  #Shows uptime,firmware version, and general system and process information
  #Requires ffi, sys-uptime, and sys-proctable gems
  get '/player_status' do
    @proctable = ProcTable.ps
    haml :player_status
  end  

end
