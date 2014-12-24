require 'simplecov'
require 'simplecov-csv'
require 'simplecov-cobertura'

#SimpleCov.formatters = [
#    SimpleCov::Formatter::HTMLFormatter,
#    SimpleCov::Formatter::CSVFormatter,
#    SimpleCov::Formatter::CoberturaFormatter
#]

SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

SimpleCov.coverage_dir(ENV['COVERAGE_REPORTS'])
SimpleCov.start
