require 'simplecov'
require 'simplecov-csv'

SimpleCov.formatter = SimpleCov::Formatter::CSVFormatter
SimpleCov.coverage_dir(ENV['COVERAGE_REPORTS'])
SimpleCov.start
