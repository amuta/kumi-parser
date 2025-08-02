# frozen_string_literal: true

require_relative 'smart_tokenizer'
require_relative 'direct_parser'
require_relative 'errors'

module Kumi
  module Parser
    # Text parser using tokenizer + direct AST construction
    class Base
      def self.parse(source, source_file: '<input>')
        tokens = SmartTokenizer.new(source, source_file: source_file).tokenize
        Kumi::Parser::DirectParser.new(tokens).parse
      end

      def self.valid?(source, source_file: '<input>')
        parse(source, source_file: source_file)
        true
      rescue Errors::TokenizerError, Errors::ParseError
        false
      end

      def self.validate(source, source_file: '<input>')
        parse(source, source_file: source_file)
        []
      rescue Errors::TokenizerError, Errors::ParseError => e
        [create_diagnostic(e, source_file)]
      end

      private

      def self.create_diagnostic(error, source_file)
        location = if error.is_a?(Errors::ParseError) && error.token
                     error.token.location
                   elsif error.respond_to?(:location)
                     error.location
                   else
                     nil
                   end

        {
          line: location&.line || 1,
          column: location&.column || 1,
          message: error.message,
          severity: :error,
          type: :syntax
        }
      end
    end
  end
end
