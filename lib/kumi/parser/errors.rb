module Kumi
  module Parser
    # Namespace for parser-related errors
    module Errors
      # Custom error for parsing issues
      class ParseError < StandardError
        attr_reader :token, :suggestions

        def initialize(message, token:, suggestions: [])
          @token = token
          @suggestions = suggestions
          super(build_error_message(message))
        end

        private

        def build_error_message(message)
          lines = ["Parse error at #{@token.location}"]
          lines << "  #{message}"

          if @suggestions.any?
            lines << '  Suggestions:'
            @suggestions.each { |s| lines << "    - #{s}" }
          end

          lines.join("\n")
        end
      end

      class TokenizerError < StandardError
        attr_reader :location

        def initialize(message, location:)
          @location = location
          super("#{message} at #{location}")
        end
      end
    end
  end
end
