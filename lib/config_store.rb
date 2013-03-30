require 'live_image'
require 'fileutils'

# A key/value store for strings.
# Right now implemented as disk files.
module ConcertoConfig
	module ConfigStore
		@@path = nil

		def self.read_config(name, default='')
			initialize_path if not @@path			
			file = File.join(@@path, name)
			rofile = File.join(@@ropath, name)

			# Check the read/write config location first. If nothing there,
			# check the read-only location. If nothing is there, return default.
			# This way writes can be made at runtime on read-only media while
			# still allowing some settings to be "baked into" the media.
			if File.exist?(file)
				IO.read(file)
			elsif File.exist?(rofile)
				IO.read(rofile)
			else
				default
			end
		end

		# Write a config to the read/write configuration location.
		def self.write_config(name, value)
			initialize_path if not @@path
			file = File.join(@@path, name)

			File.open(file, 'w') do |f|
				f.write value
			end
		end

		def self.initialize_path
			@@ropath = File.join(LiveImage.mountpoint, 'concerto', 'config')
			if LiveImage.readonly?
				@@path = '/tmp/concerto/config'
			else
				@@path = @@ropath
			end
			FileUtils.mkdir_p @@path
		end
	end
end
