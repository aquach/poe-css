# frozen_string_literal: true

require 'bundler/gem_tasks'

task :spec do
  system('cd tests && bundle exec ruby run-all-tests.rb')
end

task default: :spec
task test: :spec
