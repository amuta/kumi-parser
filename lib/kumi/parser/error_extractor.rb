# frozen_string_literal: true

module Kumi
  module Parser
    # Extracts errors from parslet parse failures
    class ErrorExtractor
      def self.extract(error)
        # Basic error extraction from parslet parse failures
        # This would typically parse the parslet error message
        # and extract location information

        return {} unless error.respond_to?(:message)

        message = error.message

        # Determine error type based on class
        error_type = case error.class.name
                     when /Syntax/ then :syntax
                     else :runtime
                     end

        # Simple regex to extract line/column info
        if match = message.match(/at line (\d+) char (\d+)/)
          line = match[1].to_i
          column = match[2].to_i
        else
          line = 1
          column = 1
        end

        # Format message based on error type
        formatted_message = if error_type == :syntax
                              extract_user_friendly_message(message)
                            else
                              "#{error.class.name}: #{message}"
                            end

        {
          message: formatted_message,
          line: line,
          column: column,
          severity: :error,
          type: error_type
        }
      end

      def self.humanize_error_message(raw_message)
        extract_user_friendly_message(raw_message)
      end

      def self.extract_user_friendly_message(raw_message)
        # Clean up the message first - remove markers, location info, and extra whitespace
        cleaned_message = raw_message.gsub(/^\s*`-\s*/, '').gsub(/ at line \d+ char \d+\.?/, '').strip

        # Convert parslet's technical error messages to user-friendly ones
        case cleaned_message
        when /Expected ":", but got "(\w+)"/
          "Missing ':' before symbol, but got \"#{::Regexp.last_match(1)}\""
        when /Expected ":"/
          "Missing ':' before symbol"
        when /Expected "do", but got "(\w+)"/
          "Missing 'do' keyword, but got \"#{::Regexp.last_match(1)}\""
        when /Expected "do"/
          "Missing 'do' keyword"
        when /Expected "end", but got (.+)/
          "Missing 'end' keyword, but got #{::Regexp.last_match(1)}"
        when /Expected "end"/
          "Missing 'end' keyword"
        when /Expected "(\w+)", but got "(\w+)"/
          "Missing '#{::Regexp.last_match(1)}' keyword, but got \"#{::Regexp.last_match(2)}\""
        when /Expected '(\w+)'/
          "Expected '#{::Regexp.last_match(1)}'"
        when /Expected "([^"]+)", but got "([^"]+)"/
          "Expected '#{::Regexp.last_match(1)}', but got \"#{::Regexp.last_match(2)}\""
        when /Expected "(\w+)"/
          "Missing '#{::Regexp.last_match(1)}' keyword"
        when /Failed to match.*Premature end of input/m
          'Failed to match - premature end of input'
        when /Premature end of input/
          "Unexpected end of file - missing 'end'?"
        when /Failed to match/
          'Failed to match sequence'
        else
          'Parse error'
        end
      end
    end
  end
end
