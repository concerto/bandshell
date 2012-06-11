require 'sinatra'
require 'haml'
require 'json'
require './netconfig'

CONFIG_FILE='/tmp/netconfig.json'
CONNECTION_METHODS = [ WiredConnection, WirelessConnection ]
ADDRESSING_METHODS = [ DHCPAddressing, StaticAddressing ]

helpers do
    def value_from(obj, method)
        if obj.respond_to? method
            obj.send method
        else
            ""
        end
    end
end

get '/' do
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

post '/' do
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

    redirect '/'
end
