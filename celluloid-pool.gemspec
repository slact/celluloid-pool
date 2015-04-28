# coding: utf-8

Gem::Specification.new do |gem|
  gem.name          = "celluloid-pool"
  gem.version       = "0.10.0.pre2"
  gem.authors       = ["Tony Arcieri", "Tim Carey-Smith", "digitalextremist //"]
  gem.email         = ['tony.arcieri@gmail.com', 'code@extremist.digital']

  gem.summary       = %q{An implementation of an actor pool, based on the Celluloid concurrent object framework.}
  gem.description   = %q{An implementation of an actor pool, based on the Celluloid concurrent object framework.}
  gem.homepage      = "http://github.com/celluloid/celluloid-pool"
  gem.license       = "MIT"

  gem.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|examples|spec|features)/}) }
  gem.require_paths = ["lib"]

  gem.add_development_dependency 'bundler'
  
  gem.add_dependency "celluloid"

end