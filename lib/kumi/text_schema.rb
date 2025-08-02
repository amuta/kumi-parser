# frozen_string_literal: true

require 'kumi'
require_relative 'text_parser'

module Kumi
  # Text-based schema that extends Kumi::Schema with text parsing capabilities
  class TextSchema
    extend Kumi::Schema
    
    # Create a schema from text using the same pipeline as Ruby DSL
    def self.from_text(text, source_file: '<input>')
      # Parse text to AST (same as RubyParser::Dsl.build_syntax_tree)
      @__syntax_tree__ = Kumi::TextParser.parse(text, source_file: source_file).freeze
      @__analyzer_result__ = Analyzer.analyze!(@__syntax_tree__).freeze
      @__compiled_schema__ = Compiler.compile(@__syntax_tree__, analyzer: @__analyzer_result__).freeze

      Inspector.new(@__syntax_tree__, @__analyzer_result__, @__compiled_schema__)
    end
    
    # Validate text schema
    def self.valid?(text, source_file: '<input>')
      Kumi::TextParser.valid?(text, source_file: source_file)
    end
    
    # Get validation diagnostics
    def self.validate(text, source_file: '<input>')
      Kumi::TextParser.validate(text, source_file: source_file)
    end
  end
end