# frozen_string_literal: true

module Kumi
  module Parser
    module TextParser
      # Simple diagnostic for online editors
      class EditorDiagnostic
        attr_reader :line, :column, :message, :severity, :type

        def initialize(line:, column:, message:, severity: :error, type: :syntax)
          @line = line
          @column = column
          @message = message
          @severity = severity
          @type = type
        end

        def to_monaco
          {
            startLineNumber: line,
            startColumn: column,
            endLineNumber: line,
            endColumn: column + 1,
            message: message,
            severity: monaco_severity
          }
        end

        def to_codemirror
          {
            from: (line - 1) * 1000 + (column - 1),
            to: (line - 1) * 1000 + column,
            message: message,
            severity: severity.to_s
          }
        end

        def to_h
          {
            line: line,
            column: column,
            message: message,
            severity: severity.to_s,
            type: type.to_s
          }
        end

        def to_json(*args)
          require 'json'
          to_h.to_json(*args)
        end

        private

        def monaco_severity
          case severity
          when :error then 8    # Monaco.MarkerSeverity.Error
          when :warning then 4  # Monaco.MarkerSeverity.Warning
          when :info then 2     # Monaco.MarkerSeverity.Info
          else 8
          end
        end
      end

      # Collection of diagnostics
      class DiagnosticCollection
        def initialize(diagnostics = [])
          @diagnostics = diagnostics
        end

        def <<(diagnostic)
          @diagnostics << diagnostic
        end

        def empty?
          @diagnostics.empty?
        end

        def count
          @diagnostics.length
        end

        def to_monaco
          @diagnostics.map(&:to_monaco)
        end

        def to_codemirror
          @diagnostics.map(&:to_codemirror)
        end

        def to_json(*args)
          require 'json'
          @diagnostics.map(&:to_h).to_json(*args)
        end

        def to_a
          @diagnostics
        end
      end
    end
  end
end
