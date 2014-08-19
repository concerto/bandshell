require 'bandshell/config_store'
require 'net/http'
require 'json'

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

    def update_if_stale
      if (last_update < Time.now - @shelf_life)
        update
      end
    end #update

    # Fetches the latest player settings from Concerto
    # TODO: Store settings in BandshellConfig (and update whenever they have
    # changed) so that configs are immediately available at boot.
    def update
      data = Bandshell::HardwareApi::get_player_info
      if data.nil?
        puts "update_player_info: Error: Recieved null data from get_player_info!"
        false
      else
        puts data
        new_rules = parse_screen_on_off(data['screen_on_off'])
        if new_rules.nil?
          false
        else
          puts "update_player_info: Updating the rules!"
          on_off_rules = new_rules
          last_update = Time.now
        end
      end
    end #update

    # TODO: more validation before accepting.
    def parse_screen_on_off(data)
      begin
        rules = JSON.parse(data)
        if rules.is_a? Array
          return rules
        else
          puts "parse_screen_on_off: Recieved something other than an aray."
          return nil
        end
      rescue
        puts "parse_screen_on_off: invalid JSON recieved"
        return nil
      end
    end

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
