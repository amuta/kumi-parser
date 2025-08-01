# frozen_string_literal: true

require_relative 'text_parser/editor_diagnostic'

module Kumi
  module Parser
    # Converts analyzer errors to editor diagnostics
    class AnalyzerDiagnosticConverter
      def self.convert_errors(errors)
        diagnostics = TextParser::DiagnosticCollection.new

        errors.each do |error|
          diagnostic = convert_single_error(error)
          diagnostics << diagnostic if diagnostic
        end

        diagnostics
      end

      def self.convert_single_error(error)
        # Handle legacy array format [location, message]
        if error.is_a?(Array) && error.size == 2
          location, message = error
          line = location&.respond_to?(:line) ? location.line : 1
          column = location&.respond_to?(:column) ? location.column : 1

          return TextParser::EditorDiagnostic.new(
            line: line,
            column: column,
            message: message.to_s,
            severity: :error,
            type: :semantic
          )
        end

        # Handle regular error objects
        if error&.respond_to?(:message)
          line = error.respond_to?(:location) && error.location&.respond_to?(:line) ? error.location.line : 1
          column = error.respond_to?(:location) && error.location&.respond_to?(:column) ? error.location.column : 1

          # Extract error type and map to severity
          error_type = error.respond_to?(:type) ? error.type : :semantic
          severity = map_type_to_severity(error_type)

          return TextParser::EditorDiagnostic.new(
            line: line,
            column: column,
            message: error.message,
            severity: severity,
            type: error_type
          )
        end

        # Handle unknown formats (strings, etc.)
        return unless error

        TextParser::EditorDiagnostic.new(
          line: 1,
          column: 1,
          message: "Unknown analyzer error: #{error}",
          severity: :error,
          type: :semantic
        )
      end

      def self.extract_location(location)
        if location&.respond_to?(:line) && location.respond_to?(:column)
          { line: location.line, column: location.column }
        else
          { line: 1, column: 1 }
        end
      end

      def self.map_type_to_severity(type)
        case type
        when :warning then :warning
        when :info then :info
        when :hint then :hint
        else :error
        end
      end
    end
  end
end
