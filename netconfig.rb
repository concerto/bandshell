#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'ipaddress'

# The big idea here is that we have connection methods (layer 2)
# and addressing methods (layer 3) and by combining that configuration
# information we end up with a complete network configuration.
#
# Each general layer-2 and layer-3 connection method is represented
# as a class; adding the specific details creates an instance of the class.
# The configuration is serialized as the name of the class plus the details
# needed to reconstruct the instance.
#
# Each instance can contribute lines to /etc/network/interfaces,
# the Debian standard network configuration file.
# Each instance also has the opportunity to write out other configuration
# files such as wpa_supplicant.conf, resolv.conf etc.

class Module
    def basename
        name.gsub(/^.*::/, '')
    end
end

module ConcertoConfig
    # Where we store the name of the interface we are going to configure.
    INTERFACE_FILE='/tmp/concerto_configured_interface'

    # The Debian interfaces configuration file we are going to write out.
    INTERFACES_FILE='/etc/network/interfaces'

    # The configuration file we will read from.
    CONFIG_FILE='/tmp/netconfig.json'

    # Some useful interface operations.
    class Interface
        # Wrap an interface name (eth0, wlan0 etc) with some useful operations.
        def initialize(name)
            @name = name
        end

        # Get the name of the interface as a string.
        attr_reader :name

        # Get the (first) IPv4 address assigned to the interface.
        # Return "0.0.0.0" if we don't have any v4 addresses.
        def ip
            if ifconfig =~ /inet addr:([0-9.]+)/
                $1
            else
                "0.0.0.0"
            end
        end

        # Get the physical (mac, ethernet) address of the interface.
        def mac
            File.open("/sys/class/net/#{@name}/address") do |f|
                f.read.chomp
            end
        end

        def up
            system("/sbin/ifconfig #{@name} up")
        end

        def down
            system("/sbin/ifconfig #{@name} down")
        end

        def ifup
            system("/sbin/ifup #{@name}")
        end

        def ifdown
            system("/sbin/ifdown #{@name}")
        end

        def up?
            if ifconfig =~ /UP/
                true
            else
                false
            end
        end

        def medium_present?
            brought_up = false
            result = false

            if not up?
                brought_up = true
                up
                sleep 10
            end

            if ifconfig =~ /RUNNING/
                result = true
            end
            
            if brought_up
                down
            end

            result
        end
    private
        def ifconfig
            `/sbin/ifconfig #{@name}`
        end
    end

    # (Instance) methods that must be defined by all connection and 
    # addressing method classes
    # 
    # creation and serialization:
    #
    # initialize(args={}): Create a new instance. When unserializing the args 
    # hash created during serialization is passed in.
    #
    # args: return a hash of data needed to reconstruct the instance. This 
    # hash will be passed to initialize() when unserializing.
    #
    # OS-level configuration:
    #
    # write_configs: Write out any additional configuration files needed 
    # (e.g. resolv.conf, wpa_supplicant.conf, ...)
    #
    # config_interface_name (only for connection methods): return the name of 
    # the physical interface to be used for the connection
    #
    # addressing_type (only for addressing methods): return the name of the 
    # addressing method (dhcp, static, manual...) to be used in the Debian
    # network configuration file /etc/network/interfaces.
    #
    # interfaces_lines: an array of strings representing lines to be added
    # to the /etc/network/interfaces file after the line naming the interface.
    #
    # Stuff for the Web interface:
    #
    # safe_assign: return an array of symbols representing fields the user 
    # should be allowed to modify.
    #
    # validate: check that the internal configuration is at least somewhat 
    # consistent and stands a chance of working; throw exception if not
    # (FIXME! need a better error handling mechanism)
    # 
    # and attr_accessors for everything the web interface 
    # should be able to assign to.
    #
    # Everyone must define a class method self.description as well.
    # This returns a string that is displayed in the web interface dropdowns
    # because using plain class identifiers there doesn't look good.
    # This should be something short like "Wired Connection".

    # Layer 2 connection via wired media.
    # We will look for wired interfaces that have media connected,
    # or use an interface chosen by the user via the args. There's
    # nothing extra to be contributed to the interfaces file besides
    # the name of the interface to be used.
    class WiredConnection
        def initialize(args={})
            if args['interface_name']
                @interface_name = args['interface_name']
            end
        end

        def write_configs
            # We don't need any.
        end

        def config_interface_name
            if @interface_name && @interface_name.length > 0
                # the user has specified an interface to use
                @interface_name
            else
                # scan for the first wired interface that has media
                scan_interfaces
            end
        end

        # If interface_name is something other than nil or the empty string,
        # we will override the automatic detection and use that interface.
        attr_accessor :interface_name

        def safe_assign
            [ :interface_name ]
        end

        def args
            {
                'interface_name' => @interface_name
            }
        end
        
        def interfaces_lines
            []
        end

        def validate
            if @interface_name != ''
                if self.class.interfaces.find { 
                        |iface| iface.name == @interface_name 
                }.nil?
                    fail "The interface doesn't exist on the system"
                end
            end  
        end

        # Try to find all wired interfaces on the system.
        def self.interfaces
            # This is somewhat Linux specific and may miss some oddballs.
            devices = Dir.glob('/sys/class/net/eth*')
            devices.map { |d| Interface.new(File.basename(d)) }
        end

        def self.description
            "Wired connection"
        end

    private
        # Find the first wired interface with medium present. If none
        # is found default to eth0.
        def scan_interfaces
            first_with_medium = self.class.interfaces.find { 
                |iface| iface.medium_present? 
            }

            if first_with_medium
                first_with_medium
            else
                # if we get here no interface was found with a cable attached
                # default to eth0 and hope for the best
                STDERR.puts "warning: no suitable interface found, using eth0"
                'eth0'
            end
        end
    end

    # 802.11* unencrypted wireless connections.
    # These are managed by wpa_supplicant on Debian so we need to create its
    # configuration file and link it to the interfaces file.
    class WirelessConnection
        def initialize(args={})
            @ssid = args['ssid'] || ''
            @interface_name = args['interface_name'] if args['interface_name']
            @wpa_config_file = '/tmp/wpa_supplicant.concerto.conf'
        end

        attr_accessor :ssid, :interface_name

        def config_interface_name
            # If the user has requested a specific interface, use it.
            # Otherwise, just pick the first wlan interface, assuming
            # it works and all wlan interfaces have approximately equal
            # reception. When this assumption is wrong the user must force.
            @interface_name || self.class.interfaces[0].name
        end

        def validate
            if @ssid == ''
                fail "Need SSID for wireless connection"
            end
        end

        def safe_assign
            [ :ssid, :interface_name ]
        end

        def write_configs
            # Write a wpa_supplicant.conf file for an unsecured network.
            File.open(@wpa_config_file, 'w') do |wpaconf|
                # long lines, sorry!
                wpaconf.puts "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel"
                wpaconf.puts "network={"
                wpaconf.puts "ssid=\"#{@ssid}\""
                wpaconf.puts "scan_ssid=1"
                wpaconf.puts "key_mgmt=NONE"
                wpaconf.puts "}"
            end
        end

        def interfaces_lines
            # This links the wpa config to the interfaces file.
            ["wpa-conf #{@wpa_config_file}"]
        end

        def args
            {
                'interface_name' => @interface_name,
                'ssid' => @ssid
            }
        end

        def self.description
            "Wireless connection (no encryption)"
        end

        def self.interfaces
            # Again this is not guaranteed to be a catch all.
            devices = Dir.glob('/sys/class/net/{ath,wlan}*')
            devices.map { |d| Interface.new(File.basename(d)) }
        end
    end

    # Static IPv4 addressing.
    # We use the IPAddress gem to validate that the address information
    # is vaguely correct (weeding out errors like the gateway 
    # being on another subnet)
    class StaticAddressing
        def initialize(args={})
            @nameservers = args['nameservers']
            @address = args['address']
            @netmask = args['netmask']
            @gateway = args['gateway']
        end

        def addressing_type
            'static'
        end

        def args
            {
                'address' => @address,
                'netmask' => @netmask,
                'gateway' => @gateway,
                'nameservers' => @nameservers
            }
        end

        def interfaces_lines
            [
                "address #{@address}",
                "netmask #{@netmask}",
                "gateway #{@gateway}"
            ]
        end


        def write_configs
            File.open('/etc/resolv.conf','w') do |resolvconf|
                @nameservers.each do |nameserver|
                    resolvconf.puts("nameserver #{nameserver}");
                end
            end
        end

        def self.description
            "Static Addressing"
        end

        attr_accessor :address, :netmask, :gateway, :nameservers

        def safe_assign
            [ :address, :netmask, :gateway, :nameservers_flat ]
        end

        def validate
            @address.strip!
            @netmask.strip!
            @gateway.strip!

            if not IPAddress.valid_ipv4?(@address)
                fail "Static address is invalid"
            end

            p @netmask
            if not IPAddress.valid_ipv4_netmask?(@netmask)
                fail "Static netmask is invalid"
            end

            p @netmask
            subnet = IPAddress::IPv4.new(@address)
            subnet.netmask = @netmask
            if not subnet.include? IPAddress::IPv4.new(gateway)
                fail "Gateway provided is unreachable"
            end
        end

        # These next two methods are for the web interface, where it's
        # more convenient to enter a bunch of nameservers on one line
        # than to have to deal with an array of fields.
        def nameservers_flat=(separated_list)
            servers = separated_list.strip.split(/\s*[,|:;\s]\s*/)
            servers.each do |server|
                server.strip!
                p server
                if not IPAddress.valid? server
                    fail "One or more invalid IP addresses in nameserver list"
                end
            end
            @nameservers = servers
        end

        def nameservers_flat
            @nameservers.join(',')
        end
    end

    # Dynamic IPv4 addressing via DHCP
    class DHCPAddressing
        def initialize(args={})
            # we accept no args
        end

        def addressing_type
            'dhcp'
        end

        def interfaces_lines
            # DHCP needs no additional interfaces args 
            # from the addressing side
            []
        end

        def validate
            # nothing to validate
        end

        def safe_assign
            [] # no args
        end

        def args
            { }
        end

        def write_configs
            # dhclient will write our resolv.conf so we do not need 
            # to do anything
        end

        def self.description
            "Dynamic Addressing - DHCP"
        end
    end

    # Read a JSON formatted network configuration from an input stream.
    # This instantiates the connection and addressing method classes
    # and returns the instances
    # i.e.
    # cm, am = read_config(STDIN)
    def self.read_config
        input = IO.read(CONFIG_FILE)
        args = JSON.parse(input)

        connection_method_class = ConcertoConfig.const_get(args['connection_method'])
        addressing_method_class = ConcertoConfig.const_get(args['addressing_method'])

        connection_method = connection_method_class.new(
            args['connection_method_args']
        )

        addressing_method = addressing_method_class.new(
            args['addressing_method_args']
        )

        return [connection_method, addressing_method]    
    end

    # This reads a JSON configuration file on STDIN and writes the interfaces
    # file. Also the classes instantiated will have a chance to write
    # out any auxiliary files needed.
    def self.configure_system
        connection_method, addressing_method = read_config

        ifname = connection_method.config_interface_name

        # squirrel away the name of the interface we are configuring
        # This will be useful later for getting network status information.
        File.open(INTERFACE_FILE, 'w') do |f|
            f.write ifname
        end
        
        # Write the /etc/network/interfaces file.
        File.open(INTERFACES_FILE, 'w') do |f|
            f.puts "# Concerto Live network configuration"
            f.puts "# Generated by netconfig.rb"
            f.puts "# Changes will be lost on reboot"
            f.puts "auto #{ifname}"
            f.puts "iface #{ifname} inet #{addressing_method.addressing_type}"

            addressing_method.interfaces_lines.each do |line|
                f.puts "\t#{line}"
            end

            connection_method.interfaces_lines.each do |line|
                f.puts "\t#{line}"
            end
        end

        # Write auxiliary configuration files.
        connection_method.write_configs
    end

    # Get the name of the interface we configured
    def self.configured_interface
        begin
            ifname = File.open(INTERFACE_FILE) do |f|
                f.readline.chomp
            end
            Interface.new(ifname)
        rescue
            nil
        end
    end
end
