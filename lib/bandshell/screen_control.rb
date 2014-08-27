# This is a stateless class which provides a collection of methods
# for controlling the display. Currently supported control interfaces
# include:
#   * DPMS
module Bandshell
  class ScreenControl 
  class << self
    # Only used if no display is set already.
    def default_display
      ":0"
    end

    # Ensures that the display is in the specified state by enforcing
    # each of a number of parameters, passed as the "state" hash.
    # Valid keys:
    #   :on => (boolean value: true for on, false for off)
    def enforce_screen_state(state)
      if !state.is_a? Hash
        raise "enforce_screen_state: did not receive a hash!"
      end
      if state.has_key? :on
        if state[:on] == true
          force_screen_on unless screen_is_on? == true
        elsif state[:on] == false
          force_screen_off unless screen_is_on? == false
        else
          raise "enforce_screen_state: Invalid value for :on!"
        end
      end
    end

    def force_screen_on
      dpms_force_screen_on
    end

    def force_screen_off
      dpms_force_screen_off
    end
    
    # true, false, or unknown
    def screen_is_on?
      dpms_screen_is_on?
    end

    # Returns a boolean and an explanatory string indicating
    # whether the screen can be controlled by DPMS.
    def control_availability
      dpms_availability
    end

    private

    #
    # DPMS Implementation
    #
    # Note: this code relies on backtick system calls. These are dangerous,
    # security-wise, so we need to ensure that no webserver-provided strings
    # are interploated.
    #
    # We make no attempt to enable or disable DPMS. I'm not sure how the
    # default is determined at a system level, but that may be an option
    # if folks run into it being off.

    # true, false, or :unknown
    def dpms_screen_is_on?
      if ENV['DISPLAY'].nil? or ENV['DISPLAY'].empty?
        ENV['DISPLAY'] = default_display
      end

      begin
        result = `xset -q 2>&1`
      rescue Errno::ENOENT
        return :unknown
      end
      if ($?.exitstatus != 0)
        return :unknown
      end
      if result.include? "Monitor is On"
        return true
      elsif result.include? "Monitor is Off"
        return false
      else
        return :unknown
      end
    end

    # true on success, false on failure.
    def dpms_force_screen_on
      if ENV['DISPLAY'].nil? or ENV['DISPLAY'].empty?
        ENV['DISPLAY'] = default_display
      end

      begin
        `xset dpms force on`
      rescue Errno::ENOENT
        return false
      end
      if $?.exitstatus != 0
        return false
      end

      # Required if the screen was turned off with DPMS and the
      # screensaver has not been disabled:
      begin
        `xset s reset`
      rescue Errno::ENOENT #unlikely, but still...
        return false
      end
      if $?.exitstatus != 0
        return false
      end
    end

    # true on success, false on failure.
    def dpms_force_screen_off
      if ENV['DISPLAY'].nil? or ENV['DISPLAY'].empty?
        ENV['DISPLAY'] = default_display
      end

      begin
        `xset dpms force off`
      rescue Errno::ENOENT
        return false
      end
      if $?.exitstatus == 0
        return true
      else
        return false
      end
    end

    def dpms_availability
      if ENV['DISPLAY'].nil? or ENV['DISPLAY'].empty?
        ENV['DISPLAY'] = default_display
      end

      begin
        result = `xset -q 2>&1`
      rescue Errno::ENOENT
        return [false, "Can't access the xset command to control DPMS."]
      end
      if ($?.exitstatus == 127)
        return [false, "Can't access the xset command to control DPMS."]
      elsif ($?.exitstatus != 0)
        # xset returns 1 and a message if the display is not specified or
        # invalid.
        return [false, "Problem running xset: "+result.chomp]
      end
      if result.include? "DPMS is Disabled"
        return [false, "DPMS is disabled."]
      elsif result.include? "DPMS is Enabled"
        return [true, ""]
      else
        return [false, "Error parsing xset output."]
      end
    end
  end # self
  end # ScreenControl
end
