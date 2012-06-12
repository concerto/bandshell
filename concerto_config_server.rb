require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require './netconfig'
require 'net/http'
require 'ipaddress'

NETCONFIG_FILE='/tmp/netconfig.json'
PASSWORD_FILE='/tmp/concerto_password'
URL_FILE='/tmp/concerto_url'

CONNECTION_METHODS = [ WiredConnection, WirelessConnection ]
ADDRESSING_METHODS = [ DHCPAddressing, StaticAddressing ]

LOCALHOSTS = [ 
    IPAddress.parse("127.0.0.1"), 
    IPAddress.parse("::1") 
]

begin
    PASSWORD = File.open(PASSWORD_FILE) do |f|
        f.readline.chomp
    end
rescue Errno::ENOENT
    PASSWORD = 'default'
end

helpers do
    def value_from(obj, method)
        if obj.respond_to? method
            obj.send method
        else
            ""
        end
    end

    def protected!
        unless authorized?
            response['WWW-Authenticate'] = %(Basic realm="Concerto Configuration")
            throw(:halt, [401, "Not authorized\n"])
        end
    end

    def authorized?
        ip = IPAddress.parse(request.env['REMOTE_ADDR'])
        if LOCALHOSTS.include? ip
            # allow all requests from localhost no questions asked
            true
        else
            @auth ||= Rack::Auth::Basic::Request.new(request.env)
            @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['root', PASSWORD]
        end
    end

    def concerto_url
        begin
            File.open(URL_FILE) do |f|
                f.readline.chomp
            end
        rescue
            ""
        end
    end

    def my_ip
        iface = configured_interface
        if iface
            iface.ip
        else
            "Network setup failed or bad configuration"
        end
    end

    def network_ok
        if configured_interface
            true
        else
            false
        end
    end

    def validate_url
        begin
            # this will fail with Errno::something if server can't be reached
            response = Net::HTTP.get_response(URI(concerto_url))
            if response.code != "200"
                # also bomb out if we don't get an OK response
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

get '/setup' do
    protected!
    if network_ok
        # Everything's up and running, we just don't know what 
        # our URL should be.
        haml :setup, :layout => :main
    else
        # The network settings are not sane, we don't have an IP.
        # Redirect the user to the network configuration page to 
        # take care of this.
        redirect '/netconfig'
    end
end

post '/setup' do
    protected!
    url = params[:url]
    if validate_url(url)
        File.open(URL_FILE, 'w') do |f|
            f.write url
        end
        
        # root will now redirect to the proper concerto_url
        redirect '/'
    else
        # the URL was no good, back to setup!
        redirect '/setup'
    end
end

# render a page indicating that the concerto_url is no good.
# this page redirects to / every 5 seconds
get '/problem' do
    haml :problem, :layout => :main
end

get '/netconfig' do
    protected!

    # parse existing config file (if any)
    begin
        cm, am = File.open(NETCONFIG_FILE) { |f| read_config(f) }
    rescue Errno::ENOENT
        cm = nil
        am = nil
    end

    # view will grab what it can from our existing 
    # connection/addressing methods
    haml :netsettings, :locals => { 
            :connection_method => cm, 
            :addressing_method => am 
        },
        :format => :html5, :layout => :main
end

# Given the name of a class, pick a class out of a list of allowed classes.
# This is used for parsing the form input for network configuration.
def pick_class(name, list)
    list.find { |klass| klass.name == name }
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
            instance.public_send((param + '=').intern, value)
        end
    end
end

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
    cmargs = extract_class_args(params, cmclass.name)
    amargs = extract_class_args(params, amclass.name)

    # Set properties on each instance given the form values passed in.
    do_assign(cmargs, cm)
    do_assign(amargs, am)

    # Check that everything is consistent. If not, we currently throw
    # an exception, which probably is not the best long term solution.
    cm.validate
    am.validate

    # Serialize our instances as JSON data to be written to the config file.
    json_data = {
        'connection_method' => cmclass.name,
        'connection_method_args' => cm.args,
        'addressing_method' => amclass.name,
        'addressing_method_args' => am.args
    }

    # Write the config file to disk.
    File.open(NETCONFIG_FILE, 'w') do |f|
        f.write json_data.to_json
    end

    # something something reload configs here something

    # Back to the network form.
    redirect '/netconfig' # as a get request
end
