# frozen_string_literal: true

require 'bundler/setup'
require 'kumi-parser'
require 'pry'
# No need to eager load - using Kumi's syntax

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Suppress warnings about potentially false-positive raise_error matchers
RSpec::Expectations.configuration.on_potential_false_positives = :nothing
