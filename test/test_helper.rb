require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter
]

SimpleCov.coverage_dir(ENV['COVERAGE_REPORTS'])
SimpleCov.start
