# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-woothee"
  gem.version       = "0.0.2"
  gem.authors       = ["TAGOMORI Satoshi"]
  gem.email         = ["tagomoris@gmail.com"]
  gem.description   = %q{parsing by Project Woothee. See https://github.com/woothee/woothee }
  gem.summary       = %q{Fluentd plugin to parse UserAgent strings with woothee parser. It adds device information or filter records with specific device types.}
  gem.homepage      = "https://github.com/tagomoris/fluent-plugin-woothee"
  gem.license       = "APLv2"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rake"
  gem.add_development_dependency "test-unit", "~> 3.0.2"
  gem.add_runtime_dependency "fluentd"
  gem.add_runtime_dependency "woothee", ">= 1.0.0"
end
