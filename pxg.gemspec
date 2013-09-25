Gem::Specification.new do |s|

	s.name        = 'pxg'
	s.version     = '1.1.0'
	s.date        = '2013-08-09'
	s.summary     = "Project managing helpers"
	s.description = "Pixelgrade Utilities"
	s.authors     = ["srcspider"]
	s.email       = 'source.spider@gmail.com'
	s.files       = ["lib/pxg.rb"]
	s.homepage    = 'http://rubygems.org/gems/pxg'
	s.license     = 'MIT'
	s.executables << 'pxg'

	# dependencies
	s.add_runtime_dependency 'git',  ['>= 1.2.6', '< 2.0']
	s.add_runtime_dependency 'json', ['>= 1.8'  , '< 2.0']

end#spec
