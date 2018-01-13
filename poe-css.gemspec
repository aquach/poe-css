# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

require 'poe-css/version'

Gem::Specification.new do |s|
  s.name = 'poe-css'
  s.version = POECSS::VERSION
  s.authors = [ 'Alex Quach' ]
  s.email = [ 'alexhquach@gmail.com' ]
  s.homepage = ''
  s.summary = 'A better way to write item filters for Path of Exile.'
  s.description = 'A better way to write item filters for Path of Exile.'

  s.files = `git ls-files`.split("\n")

  s.test_files = `git ls-files -- tests/*`.split("\n")

  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }

  s.require_paths = [ 'lib' ]

  s.add_runtime_dependency 'parslet'

  s.add_development_dependency 'bundler', '~> 1.14'
  s.add_development_dependency 'irbtools'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'rubocop'
end
