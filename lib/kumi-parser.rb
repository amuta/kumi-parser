# frozen_string_literal: true

require 'kumi'
require 'kumi/syntax/node'
require 'zeitwerk'
require 'parslet'

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/kumi-parser.rb")
loader.ignore("#{__dir__}/kumi/parser/version.rb")
loader.ignore("#{__dir__}/kumi/parser/token_constants.rb")
loader.setup

require_relative 'kumi/parser/version'
require_relative 'kumi/parser/token_constants'

module Kumi
  module Parser
    # Parser extension for Kumi DSL
  end
end
