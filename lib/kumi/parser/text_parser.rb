# frozen_string_literal: true

require_relative 'syntax_validator'

module Kumi
  module Parser
    module TextParser
      # TextParser module - all classes are autoloaded by Zeitwerk

      class << self
        # Check if text is syntactically valid
        def valid?(text, source_file: '<input>')
          validator.valid?(text, source_file: source_file)
        end

        # Validate text and return diagnostic collection
        def validate(text, source_file: '<input>')
          validator.validate(text, source_file: source_file)
        end

        # Get Monaco Editor format diagnostics
        def diagnostics_for_monaco(text, source_file: '<input>')
          validate(text, source_file: source_file).to_monaco
        end

        # Get CodeMirror format diagnostics
        def diagnostics_for_codemirror(text, source_file: '<input>')
          validate(text, source_file: source_file).to_codemirror
        end

        # Get JSON format diagnostics
        def diagnostics_as_json(text, source_file: '<input>')
          validate(text, source_file: source_file).to_json
        end

        # Parse text (compatibility method)
        def parse(text, source_file: '<input>')
          parser.parse(text, source_file: source_file)
        end

        private

        def validator
          @validator ||= SyntaxValidator.new
        end

        def parser
          @parser ||= TextParser::Parser.new
        end
      end
    end
  end
end
