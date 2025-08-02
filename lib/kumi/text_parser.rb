# frozen_string_literal: true

require_relative 'parser/text_parser'

module Kumi
  # Top-level text parser module with same interface as Ruby DSL
  module TextParser
    extend self
    
    # Parse text schema and return AST (same interface as RubyParser::Dsl.build_syntax_tree)
    def parse(text, source_file: '<input>')
      Parser::TextParser.parse(text, source_file: source_file)
    end
    
    # Validate text schema
    def valid?(text, source_file: '<input>')
      Parser::TextParser.valid?(text, source_file: source_file)
    end
    
    # Get validation diagnostics
    def validate(text, source_file: '<input>')
      Parser::TextParser.validate(text, source_file: source_file)
    end
    
    # Get Monaco Editor format diagnostics
    def diagnostics_for_monaco(text, source_file: '<input>')
      Parser::TextParser.diagnostics_for_monaco(text, source_file: source_file)
    end
    
    # Get CodeMirror format diagnostics
    def diagnostics_for_codemirror(text, source_file: '<input>')
      Parser::TextParser.diagnostics_for_codemirror(text, source_file: source_file)
    end
    
    # Get JSON format diagnostics
    def diagnostics_as_json(text, source_file: '<input>')
      Parser::TextParser.diagnostics_as_json(text, source_file: source_file)
    end
  end
end