# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongodb_queue/version'

Gem::Specification.new do |spec|
  spec.name          = 'mongodb_queue'
  spec.version       = MongoDBQueue::VERSION
  spec.authors       = ['Jesse Bowes']
  spec.email         = ['jbowes@dashingrocket.com']
  spec.summary       = 'MongoDB Messaging Queue'
  spec.description   = 'A mongoDB based messaging queue that supports multiple queues'
  spec.homepage      = 'https://github.com/dashingrocket/mongodb_queue'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'ci_reporter_test_unit'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-csv'
  spec.add_development_dependency 'simplecov-cobertura'

  spec.add_runtime_dependency 'bson_ext', '~> 1.11'
  spec.add_runtime_dependency 'mongo', '~> 1.11'
end
