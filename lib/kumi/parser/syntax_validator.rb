# frozen_string_literal: true

require_relative 'text_parser/parser'
require_relative 'text_parser/editor_diagnostic'
require_relative 'error_extractor'

module Kumi
  module Parser
    # Validates Kumi DSL syntax
    class SyntaxValidator
      def initialize
        @parser = TextParser::Parser.new
      end

      def validate(text, source_file: '<input>')
        @parser.parse(text, source_file: source_file)
        TextParser::DiagnosticCollection.new([])
      rescue StandardError => e
        # ErrorExtractor.extract returns a hash, convert it to an EditorDiagnostic
        error_hash = ErrorExtractor.extract(e)
        return TextParser::DiagnosticCollection.new([]) if error_hash.empty?

        diagnostic = TextParser::EditorDiagnostic.new(
          line: error_hash[:line],
          column: error_hash[:column],
          message: error_hash[:message],
          severity: error_hash[:severity],
          type: error_hash[:type]
        )
        TextParser::DiagnosticCollection.new([diagnostic])
      end

      def valid?(text, source_file: '<input>')
        validate(text, source_file: source_file).empty?
      end

      def first_error(text, source_file: '<input>')
        diagnostics = validate(text, source_file: source_file)
        diagnostics.empty? ? nil : diagnostics.to_a.first.message
      end
    end
  end
end
