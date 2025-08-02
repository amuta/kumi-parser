# frozen_string_literal: true

require_relative 'token_metadata'

module Kumi
  module Parser
    # Context-aware tokenizer that produces tokens with embedded semantic metadata
    class SmartTokenizer
      def initialize(source, source_file: '<input>')
        @source = source
        @source_file = source_file
        @pos = 0
        @line = 1
        @column = 1
        @context_stack = [:global]
        @tokens = []
      end

      def tokenize
        while @pos < @source.length
          skip_whitespace_except_newlines

          case current_char
          when nil then break
          when "\n" then handle_newline
          when '#' then consume_comment
          when '"' then consume_string
          when /\d/ then consume_number
          when /[a-zA-Z_]/ then consume_identifier_or_keyword
          when ':' then consume_symbol_or_colon
          else
            consume_operator_or_punctuation
          end
        end

        add_token(:eof, nil, {})
        @tokens
      end

      private

      def current_char
        return nil if @pos >= @source.length

        @source[@pos]
      end

      def peek_char(offset = 1)
        peek_pos = @pos + offset
        return nil if peek_pos >= @source.length

        @source[peek_pos]
      end

      def advance
        if current_char == "\n"
          @line += 1
          @column = 1
        else
          @column += 1
        end
        @pos += 1
      end

      def skip_whitespace_except_newlines
        advance while current_char && current_char.match?(/[ \t\r]/)
      end

      def handle_newline
        add_token(:newline, "\n", Kumi::Parser::TOKEN_METADATA[:newline])
        advance
      end

      def consume_comment
        start_column = @column
        advance # skip #

        comment_text = ''
        while current_char && current_char != "\n"
          comment_text += current_char
          advance
        end

        location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
        add_token(:comment, comment_text, Kumi::Parser::TOKEN_METADATA[:comment])
      end

      def consume_string
        start_column = @column
        advance # skip opening quote

        string_content = ''
        while current_char && current_char != '"'
          if current_char == '\\'
            advance
            # Handle escape sequences
            case current_char
            when 'n' then string_content += "\n"
            when 't' then string_content += "\t"
            when 'r' then string_content += "\r"
            when '\\' then string_content += '\\'
            when '"' then string_content += '"'
            else
              string_content += current_char if current_char
            end
          else
            string_content += current_char
          end
          advance
        end

        raise_tokenizer_error('Unterminated string literal') if current_char != '"'

        advance # skip closing quote

        location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
        @tokens << Token.new(:string, string_content, location, Kumi::Parser::TOKEN_METADATA[:string])
      end

      def consume_number
        start_column = @column
        number_str = ''
        has_dot = false

        # Consume digits and underscores, and optionally a decimal point
        while current_char && (current_char.match?(/[0-9_]/) || (!has_dot && current_char == '.'))
          if current_char == '.'
            # Make sure next character is a digit to distinguish from member access
            break unless peek_char && peek_char.match?(/\d/)

            has_dot = true
            number_str += current_char

          else
            number_str += current_char
          end
          advance
        end

        token_type = has_dot ? :float : :integer
        location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
        @tokens << Token.new(token_type, number_str, location, Kumi::Parser::TOKEN_METADATA[token_type])
      end

      def consume_identifier_or_keyword
        start_column = @column
        identifier = consume_while { |c| c.match?(/[a-zA-Z0-9_]/) }

        # Check if it's a keyword
        if keyword_type = Kumi::Parser::KEYWORDS[identifier]
          metadata = Kumi::Parser::TOKEN_METADATA[keyword_type].dup

          # Update context based on keyword
          case keyword_type
          when :schema, :input
            @context_stack.push(keyword_type)
            metadata[:opens_context] = keyword_type
          when :end
            closed_context = @context_stack.pop if @context_stack.length > 1
            metadata[:closes_context] = closed_context
          end

          location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
          @tokens << Token.new(keyword_type, identifier, location, metadata)
        else
          # It's an identifier - determine its role based on context
          metadata = Kumi::Parser::TOKEN_METADATA[:identifier].dup

          # Add context-specific metadata
          case current_context
          when :input
            metadata[:context] = :input_declaration
          when :schema
            metadata[:context] = :schema_body
          end

          location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
          @tokens << Token.new(:identifier, identifier, location, metadata)
        end
      end

      def consume_symbol_or_colon
        start_column = @column

        if peek_char && peek_char.match?(/[a-zA-Z_]/)
          # It's a symbol like :name
          advance # skip :
          symbol_name = consume_while { |c| c.match?(/[a-zA-Z0-9_]/) }

          location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
          @tokens << Token.new(:symbol, symbol_name.to_sym, location, Kumi::Parser::TOKEN_METADATA[:symbol])
        else
          # It's just a colon
          location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
          @tokens << Token.new(:colon, ':', location, Kumi::Parser::TOKEN_METADATA[:colon])
          advance
        end
      end

      def consume_operator_or_punctuation
        start_column = @column
        char = current_char

        # Handle multi-character operators
        case char
        when '='
          if peek_char == '='
            advance
            advance
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(:eq, '==', location, Kumi::Parser::TOKEN_METADATA[:eq])
          else
            raise_tokenizer_error("Unexpected '=' (did you mean '=='?)")
          end
        when '!'
          if peek_char == '='
            advance
            advance
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(:ne, '!=', location, Kumi::Parser::TOKEN_METADATA[:ne])
          else
            raise_tokenizer_error("Unexpected '!' (did you mean '!='?)")
          end
        when '>'
          if peek_char == '='
            advance
            advance
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(:gte, '>=', location, Kumi::Parser::TOKEN_METADATA[:gte])
          else
            advance
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(:gt, '>', location, Kumi::Parser::TOKEN_METADATA[:gt])
          end
        when '<'
          if peek_char == '='
            advance
            advance
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(:lte, '<=', location, Kumi::Parser::TOKEN_METADATA[:lte])
          else
            advance
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(:lt, '<', location, Kumi::Parser::TOKEN_METADATA[:lt])
          end
        else
          # Single character operators/punctuation
          token_type = CHAR_TO_TOKEN[char]
          if token_type
            metadata = Kumi::Parser::TOKEN_METADATA[token_type].dup
            location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: start_column)
            @tokens << Token.new(token_type, char, location, metadata)
            advance
          else
            raise_tokenizer_error("Unexpected character: #{char}")
          end
        end
      end

      def consume_while(&block)
        result = ''
        while current_char && block.call(current_char)
          result += current_char
          advance
        end
        result
      end

      def current_context
        @context_stack.last
      end

      def add_token(type, value, metadata)
        location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: @column)
        token = Token.new(type, value, location, metadata)
        @tokens << token
      end

      def raise_tokenizer_error(message)
        location = Kumi::Syntax::Location.new(file: @source_file, line: @line, column: @column)
        raise TokenizerError.new(message, location: location)
      end
    end

    # Custom error for tokenization issues
  end
end
