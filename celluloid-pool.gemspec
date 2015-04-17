# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "celluloid-pool"
  spec.version       = "0.8.6"
  spec.authors       = ["Tony Arcieri", "Tim Carey-Smith", "digitalextremist //"]
  spec.email         = ['tony.arcieri@gmail.com', 'code@extremist.digital']

  spec.summary       = %q{An implementation of an actor pool, based on the Celluloid concurrent object framework.}
  spec.description   = %q{An implementation of an actor pool, based on the Celluloid concurrent object framework.}
  spec.homepage      = "http://github.com/celluloid/celluloid-pool"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|examples|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'celluloid-supervision'
end
