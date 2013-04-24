require 'tempfile'

# Functions for dealing with the live image
# (where it's mounted, if it's read-only, etc)
module Bandshell
	module LiveImage
		def self.mountpoint
			if File.exist? '/etc/concerto/medium_path'
				IO.read('/etc/concerto/medium_path').chomp
			else
				# sane default for Debian Live-based systems
				# (as of 2013-04-24)
				'/lib/live/mount/medium'
			fi
		end

		def self.readonly?
			# on a readonly file system this will fail
			if not File.exist? self.mountpoint
				true
			else
				begin
					f = Tempfile.new('test', self.mountpoint)
					f.close!
					false
				rescue 
					# if the tempfile creation bombs we assume readonly
					true
				end
			end
		end
	end
end
