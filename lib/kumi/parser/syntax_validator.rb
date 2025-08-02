# frozen_string_literal: true

module Kumi
  module Parser
    # Validates Kumi DSL syntax using new parser
    class SyntaxValidator
      def validate(text, source_file: '<input>')
        Kumi::Parser::Base.validate(text, source_file: source_file)
      end

      def valid?(text, source_file: '<input>')
        validate(text, source_file: source_file).empty?
      end

      def first_error(text, source_file: '<input>')
        diagnostics = validate(text, source_file: source_file)
        diagnostics.empty? ? nil : diagnostics.first[:message]
      end
    end
  end
end
