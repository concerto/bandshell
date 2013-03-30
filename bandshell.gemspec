require 'rake'

Gem::Specification.new do |s|
	s.name			= 'bandshell'
	s.version		= '0.0.8'
	s.date			= '2013-03-30'
	s.summary		= 'Concerto Client Tools'
	s.description	= 'Client-side tools for Concerto digital signage'
	s.authors		= ['Andrew Armenia']
	s.email			= 'andrew@asquaredlabs.com'
  s.add_dependency "sinatra"
  s.add_dependency "haml"	
  s.add_dependency "sys-uptime"	 
  s.add_dependency "sys-proctable"
  s.add_dependency "ipaddress"
	s.files			= FileList[
		'lib/*.rb', 'web/*', 'web/public/*', 'web/views/*', 'bin/*'
	].to_a
	s.executables	= ['concerto_netsetup', 'concerto_configserver']
end
