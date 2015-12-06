require 'rake'

Gem::Specification.new do |s|
  s.name = 'bandshell'
  s.version = '1.6'
  s.summary = 'Concerto Client Tools'
  s.description = 'Client-side tools for Concerto digital signage'
  s.license = 'Apache-2.0'
  s.authors = ['Concerto Team']
  s.email = 'team@concerto-signage.org'
  s.add_dependency "sinatra"
  s.add_dependency "sys-uptime"   
  s.add_dependency "sys-proctable"
  s.add_dependency "ipaddress"
  s.add_dependency "daemons"
  s.add_dependency "tzinfo"
  s.files = FileList[ 'lib/**/*', 'bin/*' ].to_a
  s.executables = ['bandshelld_boot', 'bandshelld']
end
