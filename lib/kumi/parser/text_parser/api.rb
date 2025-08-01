# frozen_string_literal: true

require 'ostruct'

module Kumi
  module Parser
    module TextParser
      # Public API for TextParser
      class Api
        class << self
          def parse(text, source_file: '<input>')
            parser = Parser.new
            parser.parse(text, source_file: source_file)
          end

          def validate(text, source_file: '<input>')
            parse(text, source_file: source_file)
            []
          rescue StandardError => e
            [create_diagnostic(e, source_file)]
          end

          def valid?(text, source_file: '<input>')
            validate(text, source_file: source_file).empty?
          end

          def diagnostics_for_monaco(text, source_file: '<input>')
            validate(text, source_file: source_file)
          end

          def diagnostics_for_codemirror(text, source_file: '<input>')
            validate(text, source_file: source_file)
          end

          def diagnostics_as_json(text, source_file: '<input>')
            validate(text, source_file: source_file).map(&:to_h)
          end

          def analyze(text, source_file: '<input>')
            ast = parse(text, source_file: source_file)
            { success: true, ast: ast, diagnostics: [] }
          rescue StandardError => e
            { success: false, ast: nil, diagnostics: [create_diagnostic(e, source_file)] }
          end

          private

          def create_diagnostic(error, source_file)
            OpenStruct.new(
              line: 1,
              column: 1,
              message: error.message,
              source_file: source_file
            )
          end
        end
      end
    end
  end
end
