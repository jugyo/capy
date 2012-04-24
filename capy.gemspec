# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capy/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["jugyo"]
  gem.email         = ["jugyo.org@gmail.com"]
  gem.description   = %q{Capybara Script Runner}
  gem.summary       = %q{The capy command to run the script written in Capybara DSL.}
  gem.homepage      = "https://github.com/jugyo"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capy"
  gem.require_paths = ["lib"]
  gem.version       = Capy::VERSION

  gem.add_runtime_dependency 'slop', '~>3.1'
  gem.add_runtime_dependency 'capybara'
  gem.add_runtime_dependency 'colored'
  gem.add_runtime_dependency 'capybara-webkit'

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rr"
end
