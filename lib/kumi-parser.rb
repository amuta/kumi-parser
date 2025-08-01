# frozen_string_literal: true

require 'kumi'
require 'zeitwerk'
require 'parslet'

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/kumi-parser.rb")
loader.ignore("#{__dir__}/kumi/parser/version.rb")
loader.setup

require_relative 'kumi/parser/version'

module Kumi
  module Parser
    # Parser extension for Kumi DSL
  end
end
