# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sprockets-derailleur/version'

Gem::Specification.new do |gem|
  gem.name          = "sprockets-derailleur"
  gem.version       = Sprockets::Derailleur::VERSION
  gem.authors       = ["Steel Fu"]
  gem.email         = ["steelfu@gmail.com"]
  gem.description   = %q{Speed up sprockets compiling by forking processes}
  gem.summary       = %q{Multi process sprockets compiling}
  gem.homepage      = "https://github.com/steel/sprockets-derailleur"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'sprockets', ">= 2"
end
