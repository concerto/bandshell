#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'ipaddress'

class Interface
    def initialize(name)
        @name = name
    end

    def name
        @name
    end

    def mac
        File.open("/sys/class/net/#{name}/address") do |f|
            f.read.chomp
        end
    end
end

class WiredConnection
    def initialize(args={})
        if args['interface_name']
            @interface_name = args['interface_name']
        end
    end

    # Write any necessary auxiliary configuration files
    def write_configs
        # We don't need any.
    end

    # Return the name of the interface to be configured.
    def config_interface_name
        if @interface_name
            # the user has specified an interface to use
            @interface_name
        else
            # scan for the first wired interface that has media
            scan_interfaces
        end
    end

    attr_accessor :interface_name

    # list of methods allowed to be called by name through the web interface
    def safe_assign
        [ :interface_name ]
    end

    def args
        {
            'interface_name' => @interface_name
        }
    end
    
    # Return any additional lines needed in the interfaces file
    # e.g. referencing WPA config files...
    def interfaces_lines
        # Nothing special needed for wired connections.
        []
    end

    def validate
        if @interface_name != ''
            if self.class.interfaces.find { |iface| iface.name == @interface_name }.nil?
                fail "The interface doesn't exist on the system"
            end
        end  
    end

    def self.interfaces
        # This is somewhat Linux specific, and may not be all encompassing.
        devices = Dir.glob('/sys/class/net/eth*')
        devices.map { |d| Interface.new(File.basename(d)) }
    end

    def self.description
        "Wired connection"
    end

private
    def interface_connected(iface)
        results = `/sbin/mii-tool #{iface.name}`
        if results =~ /link ok/
            true
        else
            false
        end
    end

    def up(iface)
        system("ifconfig #{iface.name} up")
    end

    def down(iface)
        system("ifconfig #{iface.name} down")
    end

    def scan_interfaces
        self.class.interfaces.each do |iface|
            up(iface)
            sleep 10
            if interface_connected(iface)
                down(iface)
                return iface.name
            end
            down(iface)
        end

        # if we get here no interface was found with a cable attached
        # default to eth0 and hope for the best
        STDERR.puts "warning: no suitable interface found, defaulting to eth0"
        'eth0'
    end
end

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
        # This is somewhat Linux specific, and may not be all encompassing.
        devices = Dir.glob('/sys/class/net/{ath,wlan}*')
        devices.map { |d| Interface.new(File.basename(d)) }
    end
end

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
            fail "Static gateway is not on the local subnet, this won't work"
        end
    end

    def nameservers_flat=(separated_list)
        servers = separated_list.strip.split(/\s*[,|:;\s]\s*/)
        servers.each do |server|
            server.strip!
            p server
            if not IPAddress.valid? server
                fail "One or more invalid IP addresses in name server list"
            end
        end
        @nameservers = servers
    end

    def nameservers_flat
        @nameservers.join(',')
    end
end

class DHCPAddressing
    def initialize(args={})
        # we accept no args
    end

    def addressing_type
        'dhcp'
    end

    def interfaces_lines
        # DHCP needs no additional interfaces args from the addressing side
        []
    end

    def validate

    end

    def safe_assign
        [] # no args
    end

    def args
        { }
    end

    def write_configs
        # dhclient will write our resolv.conf so we do not need to do anything
    end

    def self.description
        "Dynamic Addressing - DHCP"
    end
end

def read_config(input)
    input = input.read
    args = JSON.parse(input)

    connection_method_class = Object.const_get(args['connection_method'])
    addressing_method_class = Object.const_get(args['addressing_method'])

    connection_method = connection_method_class.new(
        args['connection_method_args']
    )

    addressing_method = addressing_method_class.new(
        args['addressing_method_args']
    )

    return [connection_method, addressing_method]    
end

def configure_system
    connection_method, addressing_method = read_config(STDIN)

    ifname = connection_method.config_interface_name

    puts "# Concerto Live network configuration"
    puts "# Generated by netconfig.rb"
    puts "# Changes will be lost on reboot"
    puts "auto #{ifname}"
    puts "iface #{ifname} inet #{addressing_method.addressing_type}"

    addressing_method.interfaces_lines.each do |line|
        puts "\t#{line}"
    end

    connection_method.interfaces_lines.each do |line|
        puts "\t#{line}"
    end

    connection_method.write_configs
end
