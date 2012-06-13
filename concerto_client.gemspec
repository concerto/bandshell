require 'rake'

Gem::Specification.new do |s|
	s.name			= 'concerto_client'
	s.version		= '0.0.4'
	s.date			= '2012-06-12'
	s.summary		= 'Concerto Client Tools'
	s.description	= 'Client-side tools for Concerto digital signage'
	s.authors		= ['Andrew Armenia']
	s.email			= 'andrew@asquaredlabs.com'
	s.files			= FileList[
		'lib/**/*.rb', 'lib/concerto_client/application/public/*',
		'lib/concerto_client/application/views/*.haml', 'bin/*'
	].to_a
	s.executables	= ['concerto_netsetup', 'concerto_configserver']
end
