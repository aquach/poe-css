# frozen_string_literal: true

require 'minitest'
require 'minitest/autorun'
require 'minitest/reporters'

require_relative '../lib/dependencies'

Dir.glob('unit/**/*-test.rb').each do |t|
  require_relative t
end

TEST_FILES = Dir.glob('**/*.{preprocessor,poecss}').map { |input_file|
  ext = File.extname(input_file)
  expected_to_error = !!File.basename(input_file, ext)[/\.error$/]
  output_file =
    begin
      f = File.join(File.dirname(input_file), File.basename(input_file, ext) + '.output')

      if !File.exist?(f) && !expected_to_error
        raise "Couldn't find output file #{f} for input file #{input_file}."
      end

      f
    end

  [
    input_file,
    output_file,
    "test_#{input_file.gsub(/[^a-zA-Z_0-9]/, '_')}".to_sym,
    preprocessor: ext == '.preprocessor',
    expected_to_error: expected_to_error
  ]
}

duplicate_test_name = TEST_FILES.group_by { |_, _, n| n }.find { |_, v| v.length > 1 }&.first
raise "Duplicate test name: #{duplicate_test_name}." if duplicate_test_name

class Tests < Minitest::Test
  TEST_FILES.each do |input_file, output_file, test_name, options|
    define_method(test_name) do
      input = File.read(input_file)

      get_output = proc {
        if options[:preprocessor]
          input_without_comments = input.split("\n").map { |l| l.gsub(/#.*$/, '') }.join("\n")
          POECSS::Preprocessor.compile(input_without_comments)
        else
          POECSS.compile(input)
        end
      }

      if options[:expected_to_error]
        assert_raises(&get_output)
      else
        assert_equal File.read(output_file).strip, get_output.call.strip
      end
    end
  end
end
