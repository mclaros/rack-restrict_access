# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack/restrict_access/version'

Gem::Specification.new do |spec|
  spec.name          = "rack-restrict_access"
  spec.version       = Rack::RestrictAccess::VERSION
  spec.authors       = ["Mainor Claros"]
  spec.email         = ["mainor@violetgrey.com"]
  spec.summary       = %q{Middleware to add basic auth, or block, specific host paths and requester IPs.}
  spec.description   = %q{Compares env 'REMOTE_ADDR' and 'PATH_INFO' against user-defined values to block (403), restrict (401 basic auth), or allow access to the rack app. Intended for use in simple access control. Should not be considered a security solution.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.4"
  spec.add_development_dependency "rspec-nc"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-remote"
  spec.add_development_dependency "pry-nav"
  spec.add_runtime_dependency "rack"
end
