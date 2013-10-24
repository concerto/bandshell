path= File.join(File.dirname(__FILE__), '..', '..')
$LOAD_PATH.unshift(path)

require './app.rb'
run ConcertoConfigServer
