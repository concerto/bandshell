# Functions for dealing with the live image
# (where it's mounted, if it's read-only, etc)
module ConcertoConfig
	module LiveImage
		def self.mountpoint
			'/live/image'
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
				rescue Errno::EROFS
					true
				end
			end
		end
	end
end
