require 'sinatra'
require 'haml'
require 'json'
require './netconfig'

CONFIG_FILE='/tmp/netconfig.json'
PASSWORD_FILE='/tmp/concerto_password'
CONNECTION_METHODS = [ WiredConnection, WirelessConnection ]
ADDRESSING_METHODS = [ DHCPAddressing, StaticAddressing ]

begin
    PASSWORD = File.open(PASSWORD_FILE) do |f|
        f.read
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
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['root', PASSWORD]
    end
end

get '/netconfig' do
    protected!
    # parse config file
    begin
        cm, am = File.open(CONFIG_FILE) { |f| read_config(f) }
    rescue Errno::ENOENT
        cm = nil
        am = nil
    end

    haml :netsettings, :locals => { 
            :connection_method => cm, 
            :addressing_method => am 
        },
        :format => :html5, :layout => :main
end

def pick_class(name, list)
    list.find { |klass| klass.name == name }
end

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
    cmclass = pick_class(params[:connection_type], CONNECTION_METHODS)
    fail "Connection method not supported" if cmclass.nil?
    
    amclass = pick_class(params[:addressing_type], ADDRESSING_METHODS)
    fail "Addressing method not supported" if amclass.nil?

    cm = cmclass.new
    am = amclass.new
    
    cmargs = extract_class_args(params, cmclass.name)
    amargs = extract_class_args(params, amclass.name)

    do_assign(cmargs, cm)
    do_assign(amargs, am)

    cm.validate
    am.validate

    json_data = {
        'connection_method' => cmclass.name,
        'connection_method_args' => cm.args,
        'addressing_method' => amclass.name,
        'addressing_method_args' => am.args
    }

    File.open(CONFIG_FILE, 'w') do |f|
        f.write json_data.to_json
    end

    redirect '/netconfig' # as a get request
end
