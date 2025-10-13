# frozen_string_literal: true

require 'bundler/setup'
require 'kumi-parser'
# No need to eager load - using Kumi's syntax

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Suppress warnings about potentially false-positive raise_error matchers
RSpec::Expectations.configuration.on_potential_false_positives = :nothing

Kumi.configure do |config|
  # This ensures we are testing the Ahead-of-Time compilation path.
  config.compilation_mode = :jit

  # Use a dedicated, temporary directory for test caches to avoid
  # polluting the system's tmp or a developer's local dev cache.
  config.cache_path = File.expand_path('../tmp/kumi_cache_test', __dir__)

  # Ensure tests are isolated and don't rely on a warm cache.
  config.force_recompile = true
end
