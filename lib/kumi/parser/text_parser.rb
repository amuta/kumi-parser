# frozen_string_literal: true

require_relative 'smart_tokenizer'
require_relative 'direct_parser'
require_relative 'errors'

module Kumi
  module Parser
    module TextParser
      # Clean text parser focused on core parsing functionality

      class << self
        # Parse text to AST
        def parse(text, source_file: '<input>')
          tokens = Kumi::Parser::SmartTokenizer.new(text, source_file: source_file).tokenize
          Kumi::Parser::DirectParser.new(tokens).parse
        rescue Kumi::Parser::Errors::ParseError, Kumi::Parser::Errors::TokenizerError => e
          # Convert parser errors to the expected SyntaxError for compatibility
          raise Kumi::Errors::SyntaxError, e.message
        end

        # Check if text is syntactically valid
        def valid?(text, source_file: '<input>')
          parse(text, source_file: source_file)
          true
        rescue StandardError => e
          false
        end

        # Basic validation - returns array of error hashes
        def validate(text, source_file: '<input>')
          # Use SyntaxValidator for proper diagnostic extraction
          validator = Kumi::Parser::SyntaxValidator.new
          validator.validate(text, source_file: source_file)
        end
      end
    end
  end
end
