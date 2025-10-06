module Kumi
  module Parser
    module Helpers
      # Parses optional ", domain: ..., index: :sym" (order-agnostic, both optional)
      # Cursor is right after the array/hash/type name.
      def parse_optional_decl_kwargs
        domain = nil
        index  = nil

        # nothing to do
        return [domain, index] unless current_token.type == :comma

        # consume one or more ", key: value" pairs
        while current_token.type == :comma
          advance
          key_tok = current_token

          unless key_tok.type == :label && %w[domain index].include?(key_tok.value)
            # roll back gracefully if it's not a kw pair
            @pos -= 1
            break
          end

          advance

          case key_tok.value
          when 'domain'
            domain = parse_domain_specification
          when 'index'
            sym = expect_token(:symbol)
            index = sym.value.to_sym
          end
        end

        [domain, index]
      end

      def convert_literal_value(token)
        case token.type
        when :integer  then token.value.gsub('_', '').to_i
        when :float    then token.value.gsub('_', '').to_f
        when :string   then token.value
        when :boolean  then token.value == 'true'
        when :symbol   then token.value.to_sym
        when :constant
          case token.value
          when 'Float::INFINITY' then Float::INFINITY
          else
            raise_parse_error("Unknown constant: #{token.value}")
          end
        end
      end

      def parse_kw_literal_value
        t = current_token
        case t.type
        when :integer  then advance
                            t.value.delete('_').to_i
        when :float    then advance
                            t.value.delete('_').to_f
        when :string, :symbol then advance
                                   t.value
        when :boolean  then advance
                            t.value == 'true'
        when :label    then advance
                            t.value.to_sym # :wrap, :clamp, etc.
        when :subtract # allow negatives like -1
          advance
          v = parse_kw_literal_value
          raise_parse_error("numeric after unary '-'") unless v.is_a?(Numeric)
          -v
        else
          raise_parse_error('keyword value must be literal/label')
        end
      end

      def parse_args_and_opts_inside_parens
        args = []
        opts = {}

        # expect_token(:lparen)

        unless current_token.type == :rparen
          # --- positional args ---
          unless next_is_kwarg_after_comma?
            args << parse_expression
            while current_token.type == :comma && !next_is_kwarg_after_comma?
              advance
              args << parse_expression
            end
          end
          # --- kwargs (labels like `policy:`) ---
          if next_is_kwarg_after_comma?
            # subsequent pairs: `, label value`
            while current_token.type == :comma
              # stop if next token is not a kw key
              advance

              if current_token.type == :label
                key = current_token.value.to_sym
                advance
              end
              opts[key] = parse_kw_literal_value

              break unless next_is_kwarg_after_comma?
            end
          end
        end

        expect_token(:rparen)
        [args, opts]
      end

      def expect_field_name_token
        token = current_token
        if token.identifier? || token.keyword?
          advance
          token.value
        else
          raise_parse_error("Expected field name (identifier or keyword), got #{token.type}")
        end
      end

      def next_is_kwarg_after_comma?
        current_token.type == :comma && peek_token.type == :label
      end

      def skip_comments_and_newlines
        advance while %i[newline comment].include?(current_token.type)
      end

      def advance_and_return_token
        token = current_token
        advance
        token
      end

      def map_operator_token_to_function_name(token_type)
        case token_type
        when :eq  then :==
        when :ne  then :!=
        when :gt  then :>
        when :lt  then :<
        when :gte then :>=
        when :lte then :<=
        when :and then :and
        when :or  then :or
        when :exponent then :power
        else token_type
        end
      end
    end
  end
end
