require 'bandshell/config_store'
require 'net/http'
require 'json'

# This class can be thought of as a singleton model which retrieves,
# manipulates, and stores information about the Player received from
# the Concerto server's concerto-hardware plugin. For example, it
# keeps track of screen on/off times.
module Bandshell
  class PlayerInfo
    attr_accessor :last_update
    attr_accessor :on_off_rules
    attr_accessor :shelf_life

    def initialize
      @last_update  = Time.new(0)
      @shelf_life   = 60*5
      @on_off_rules = [{"action"=>"on"}] # default to always-on
    end

    # Returns false on failure.
    def update_if_stale
      if (@last_update < Time.now - @shelf_life)
        update
      else
        true
      end
    end #update

    # Fetches the latest player settings from Concerto
    # TODO: Store settings in BandshellConfig (and update whenever they have
    # changed) so that configs are immediately available at boot.
    # Returns true on success, false on failure.
    def update
      data = Bandshell::HardwareApi::get_player_info
      if data.nil?
        puts "update_player_info: Recieved null data from get_player_info!"
      elsif data == :stat_serverr
        puts "update_player_info: Server error while retrieving player info."
      elsif data == :stat_badauth
        puts "update_player_info: Auth error while retrieving player info."
      else
        new_rules = data['screen_on_off']
        if new_rules.nil? or !new_rules.is_a? Array
          puts "update_player_info: Invalid screen on/off rules received."
        else
          @on_off_rules = new_rules
          puts @on_off_rules.to_json
          puts self.on_off_rules.to_json
          @last_update = Time.now
          return true
        end
      end
      return false
    end #update

    # Returns true if the screen should be turned on right now,
    # according to the latest data recieved from concerto-hardware.
    # Assumes on_off_rules is either nil or a valid ruleset.
    # TODO: Evaluate effects of timezones
    def screen_scheduled_on?
      return true if on_off_rules.nil?

      results = []
      t = Time.now
      on_off_rules.each do |rule|
        rule_active = true
        rule.each do |key, value|
          case key
          when "wkday"
            rule_active = false unless value.include? t.wday.to_s
          when "time_after"
            rule_secs = seconds_since_midnight(Time.parse(value))
            curr_secs = seconds_since_midnight(t)
            rule_active = false unless curr_secs > rule_secs
          when "time_before"
            rule_secs = seconds_since_midnight(Time.parse(value))
            curr_secs = seconds_since_midnight(t)
            rule_active = false unless curr_secs < rule_secs 
          when "date"
            day = Time.parse(value)
            rule_active = false unless t.year==day.year and t.yday==day.yday
          when "action"
            # Do nothing.
          else
            # Do nothing.
            # Err on the side of being on too long.
          end # case key
        end
        if rule_active and rule.has_key? "action"
          results << rule["action"]
        end
      end # each rule

      if results.include? "force_on"
        return true
      elsif results.include? "off"
        return false
      elsif results.include? "on"
        return true
      else # All rules failed
        return false
      end
    end #screen_scheduled_on?

    # For a given time object, gives a numeric representation of the
    # time of day on the day it represents.
    def seconds_since_midnight(time)
      time.sec + (time.min * 60) + (time.hour * 3600)
    end


  end #class
end #module
