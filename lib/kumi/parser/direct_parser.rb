# frozen_string_literal: true

module Kumi
  module Parser
    # Direct AST construction parser using recursive descent with embedded token metadata
    class DirectParser
      def initialize(tokens)
        @tokens = tokens
        @pos = 0
      end

      def parse
        skip_comments_and_newlines
        schema_node = parse_schema
        skip_comments_and_newlines
        expect_token(:eof)
        schema_node
      end

      private

      def current_token
        @tokens[@pos] || @tokens.last # Return EOF if past end
      end

      def peek_token(offset = 1)
        peek_pos = @pos + offset
        return @tokens.last if peek_pos >= @tokens.length # Return EOF

        @tokens[peek_pos]
      end

      def advance
        @pos += 1 if @pos < @tokens.length - 1
      end

      def expect_token(expected_type)
        raise_parse_error("Expected #{expected_type}, got #{current_token.type}") if current_token.type != expected_type
        token = current_token
        advance
        token
      end

      def skip_newlines
        advance while current_token.type == :newline
      end

      def skip_comments_and_newlines
        advance while %i[newline comment].include?(current_token.type)
      end

      # Schema: 'schema' 'do' ... 'end'
      def parse_schema
        schema_token = expect_token(:schema)
        expect_token(:do)

        skip_comments_and_newlines
        input_declarations = parse_input_block

        value_declarations = []
        trait_declarations = []

        skip_comments_and_newlines
        while %i[value trait let].include?(current_token.type)
          case current_token.type
          when :value
            value_declarations << parse_value_declaration
          when :let
            value_declarations << parse_let_value_declaration
          when :trait
            trait_declarations << parse_trait_declaration
          end
          skip_comments_and_newlines
        end

        expect_token(:end)

        Kumi::Syntax::Root.new(
          input_declarations,
          value_declarations, # values
          trait_declarations,
          loc: schema_token.location
        )
      end

      # Input block: 'input' 'do' ... 'end'
      def parse_input_block
        expect_token(:input)
        expect_token(:do)

        declarations = []
        skip_comments_and_newlines

        until %i[end eof].include?(current_token.type)
          break unless current_token.metadata[:category] == :type_keyword

          declarations << parse_input_declaration
          skip_comments_and_newlines
        end

        expect_token(:end)
        declarations
      end

      # Input declaration: 'integer :name' or 'array :items do ... end' or 'element :type, :name'
      #
      # IMPORTANT: For array nodes with a block, this sets the node's access_mode:
      #   - :element if the block contains exactly one child introduced by `element`
      #   - :field   otherwise
      def parse_input_declaration
        type_token = current_token
        unless type_token.metadata[:category] == :type_keyword
          raise_parse_error("Expected type keyword, got #{type_token.type}")
        end
        advance

        # element :type, :name  (syntactic sugar: the child was declared via `element`)
        declared_with_element = (type_token.metadata[:type_name] == :element)
        declared_with_index = (type_token.metadata[:type_name] == :index)
        if declared_with_element
          element_type_token = expect_token(:symbol)
          expect_token(:comma)
          name_token = expect_token(:symbol)
          actual_type = element_type_token.value
        elsif declared_with_index
          name_token  = expect_token(:symbol)
          actual_type = :index
        else
          name_token  = expect_token(:symbol)
          actual_type = type_token.metadata[:type_name]
        end

        # Optional: ', domain: ...'
        domain = nil
        if current_token.type == :comma
          advance
          if current_token.type == :identifier && current_token.value == 'domain'
            advance
            expect_token(:colon)
            domain = parse_domain_specification
          else
            @pos -= 1
          end
        end

        # Parse nested declarations for block forms
        children = []
        any_element_children = false
        any_field_children   = false

        if %i[array hash element].include?(actual_type) && current_token.type == :do
          advance # consume 'do'
          skip_comments_and_newlines

          until %i[end eof].include?(current_token.type)
            break unless current_token.metadata[:category] == :type_keyword

            # Syntactic decision (NO counting): is this child introduced by `element`?
            child_is_element_keyword = (current_token.metadata[:type_name] == :element)
            child_is_index_keyword   = (current_token.metadata[:type_name] == :index)
            any_element_children ||= child_is_element_keyword
            any_field_children   ||= !child_is_element_keyword && !child_is_index_keyword

            children << parse_input_declaration
            skip_comments_and_newlines
          end

          expect_token(:end)

          # For array blocks, access_mode derives strictly from syntax:
          # - :element if ANY direct child used `element`
          # - :field   if NONE used `element`
          # Mixing is invalid.
          if actual_type == :array
            if any_element_children && any_field_children
              raise_parse_error("array :#{name_token.value} mixes `element` and field children; choose one style")
            end
            access_mode = any_element_children ? :element : :field
          else
            access_mode = :field # objects/hashes with blocks behave like field containers
          end
        else
          access_mode = nil # leaves carry no access_mode
        end

        if children.empty?
          Kumi::Syntax::InputDeclaration.new(
            name_token.value,
            domain,
            actual_type,
            children,
            loc: type_token.location
          )
        else
          # 5th positional arg in your existing ctor is access_mode
          Kumi::Syntax::InputDeclaration.new(
            name_token.value,
            domain,
            actual_type,
            children,
            access_mode || :field,
            loc: type_token.location
          )
        end
      end

      def parse_domain_specification
        case current_token.type
        when :lbracket
          array_expr = parse_array_literal
          convert_array_expression_to_ruby_array(array_expr)
        when :integer, :float
          parse_range_domain
        else
          advance until %i[comma newline eof end].include?(current_token.type)
          nil
        end
      end

      def parse_range_domain
        start_token = current_token
        start_value = start_token.type == :integer ? start_token.value.to_i : start_token.value.to_f
        advance

        case current_token.type
        when :dot_dot
          advance
          end_token = current_token
          end_value = end_token.type == :integer ? end_token.value.to_i : end_token.value.to_f
          advance
          (start_value..end_value)
        when :dot_dot_dot
          advance
          end_token = current_token
          end_value = end_token.type == :integer ? end_token.value.to_i : end_token.value.to_f
          advance
          (start_value...end_value)
        else
          [start_value]
        end
      end

      def convert_array_expression_to_ruby_array(array_expr)
        return nil unless array_expr.is_a?(Kumi::Syntax::ArrayExpression)

        array_expr.elements.map do |element|
          if element.is_a?(Kumi::Syntax::Literal)
            element.value
          else
            element
          end
        end
      end

      # Value declaration: 'value :name, expression' or 'value :name do ... end'
      def parse_value_declaration
        value_token = expect_token(:value)
        name_token = expect_token(:symbol)

        if current_token.type == :do
          expression = parse_cascade_expression
        else
          expect_token(:comma)
          expression = parse_expression
        end

        Kumi::Syntax::ValueDeclaration.new(
          name_token.value,
          expression,
          loc: value_token.location
        )
      end

      def parse_let_value_declaration
        let_token = expect_token(:let)
        name_token = expect_token(:symbol)

        if current_token.type == :do
          expression = parse_cascade_expression
        else
          expect_token(:comma)
          expression = parse_expression
        end

        Kumi::Syntax::ValueDeclaration.new(
          name_token.value,
          expression,
          hints:{inline: true},
          loc: let_token.location
        )
      end

      # Trait declaration: 'trait :name, expression'
      def parse_trait_declaration
        trait_token = expect_token(:trait)
        name_token = expect_token(:symbol)
        expect_token(:comma)
        expression = parse_expression

        Kumi::Syntax::TraitDeclaration.new(
          name_token.value,
          expression,
          loc: trait_token.location
        )
      end

      # Cascade expression: 'do' cases 'end'
      def parse_cascade_expression
        start_token = expect_token(:do)
        cases = []
        skip_comments_and_newlines
        while %i[on base].include?(current_token.type)
          cases << parse_case_expression
          skip_comments_and_newlines
        end
        expect_token(:end)
        Kumi::Syntax::CascadeExpression.new(cases, loc: start_token.location)
      end

      def parse_case_expression
        case current_token.type
        when :on
          on_token = advance_and_return_token

          expressions = []
          expressions << parse_expression
          while current_token.type == :comma
            advance
            expressions << parse_expression
          end

          result = expressions.pop
          conditions = expressions
          condition =
            if conditions.length == 1
              c = conditions[0]
              simple_trait_reference?(c) ? wrap_condition_in_all(c) : c
            else
              Kumi::Syntax::CallExpression.new(:cascade_and, conditions, loc: on_token.location)
            end

          Kumi::Syntax::CaseExpression.new(condition, result, loc: on_token.location)

        when :base
          base_token = advance_and_return_token
          result = parse_expression
          true_literal = Kumi::Syntax::Literal.new(true, loc: base_token.location)
          Kumi::Syntax::CaseExpression.new(true_literal, result, loc: base_token.location)

        else
          raise_parse_error("Expected 'on' or 'base' in cascade expression")
        end
      end

      def advance_and_return_token
        token = current_token
        advance
        token
      end

      # Pratt parser for expressions
      def parse_expression(min_precedence = 0)
        left = parse_primary_expression
        skip_comments_and_newlines

        while current_token.operator? && current_token.precedence >= min_precedence
          operator_token = current_token
          advance
          skip_comments_and_newlines

          next_min_precedence =
            if operator_token.left_associative?
              operator_token.precedence + 1
            else
              operator_token.precedence
            end

          right = parse_expression(next_min_precedence)
          left = Kumi::Syntax::CallExpression.new(
            map_operator_token_to_function_name(operator_token.type),
            [left, right],
            loc: operator_token.location
          )
          skip_comments_and_newlines
        end

        left
      end

      def parse_primary_expression
        token = current_token

        case token.type
        when :integer, :float, :string, :boolean, :constant
          value = convert_literal_value(token)
          advance
          Kumi::Syntax::Literal.new(value, loc: token.location)
        when :function_sugar
          parse_function_sugar

        when :identifier

          if token.value == 'input' && peek_token.type == :dot
            parse_input_reference
          elsif peek_token.type == :lbracket
            parse_array_access_reference
          else
            advance
            Kumi::Syntax::DeclarationReference.new(token.value.to_sym, loc: token.location)
          end

        when :input
          if peek_token.type == :dot
            parse_input_reference_from_input_token
          else
            raise_parse_error("Unexpected 'input' keyword in expression")
          end

        when :lparen
          advance
          expr = parse_expression
          expect_token(:rparen)
          expr

        when :lbracket
          parse_array_literal

        when :left_brace
          parse_hash_literal

        when :fn
          # expect_token(:fn)
          parse_function_call

        when :subtract
          advance
          skip_comments_and_newlines
          operand = parse_primary_expression
          Kumi::Syntax::CallExpression.new(
            :subtract,
            [Kumi::Syntax::Literal.new(0, loc: token.location), operand],
            loc: token.location
          )

        when :newline, :comment
          skip_comments_and_newlines
          parse_primary_expression

        else
          raise_parse_error("Unexpected token in expression: #{token.type}")
        end
      end

      def parse_input_reference
        input_token = expect_token(:identifier) # 'input'
        expect_token(:dot)

        path = [expect_field_name_token.to_sym]
        while current_token.type == :dot
          advance
          path << expect_field_name_token.to_sym
        end

        if path.length == 1
          Kumi::Syntax::InputReference.new(path.first, loc: input_token.location)
        else
          Kumi::Syntax::InputElementReference.new(path, loc: input_token.location)
        end
      end

      def parse_input_reference_from_input_token
        input_token = expect_token(:input)
        expect_token(:dot)

        path = [expect_field_name_token.to_sym]
        while current_token.type == :dot
          advance
          path << expect_field_name_token.to_sym
        end

        if path.length == 1
          Kumi::Syntax::InputReference.new(path.first, loc: input_token.location)
        else
          Kumi::Syntax::InputElementReference.new(path, loc: input_token.location)
        end
      end

      def parse_array_access_reference
        name_token = expect_token(:identifier)
        expect_token(:lbracket)
        index_expr = parse_expression
        expect_token(:rbracket)

        base_ref = Kumi::Syntax::DeclarationReference.new(name_token.value.to_sym, loc: name_token.location)
        Kumi::Syntax::CallExpression.new(:at, [base_ref, index_expr], loc: name_token.location)
      end

      def parse_function_sugar
        sugar = current_token
        advance # e.g. shift(...)
        expect_token(:lparen)
        args, opts = parse_args_and_opts_inside_parens
        Kumi::Syntax::CallExpression.new(sugar.value.to_sym, args, opts, loc: sugar.location)
      end

      def parse_function_call
        advance # saw :fn
        expect_token(:lparen)
        fn_name_token = expect_token(:symbol) # :shift, :roll, etc.
        args = []
        opts = {}
        if current_token.type == :comma
          advance
          args, opts = parse_args_and_opts_inside_parens
        end
        # expect_token(:rparen)
        Kumi::Syntax::CallExpression.new(fn_name_token.value, args, loc: fn_name_token.location, opts: opts)
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

      def next_is_kwarg_after_comma?
        current_token.type == :comma && peek_token.type == :label
      end

      def parse_array_literal
        start_token = expect_token(:lbracket)
        elements = []
        unless current_token.type == :rbracket
          elements << parse_expression
          while current_token.type == :comma
            advance
            elements << parse_expression unless current_token.type == :rbracket
          end
        end
        expect_token(:rbracket)
        Kumi::Syntax::ArrayExpression.new(elements, loc: start_token.location)
      end

      def parse_hash_literal
        start_token = expect_token(:left_brace)
        skip_comments_and_newlines
        pairs = []

        # Handle empty hash: {}
        unless current_token.type == :right_brace
          pairs << parse_hash_pair
          skip_comments_and_newlines

          while current_token.type == :comma
            advance
            skip_comments_and_newlines
            # Allow trailing comma
            break if current_token.type == :right_brace

            pairs << parse_hash_pair
            skip_comments_and_newlines
          end
        end

        expect_token(:right_brace)
        Kumi::Syntax::HashExpression.new(pairs, loc: start_token.location)
      end

      def parse_hash_pair
        key_token = current_token

        key_value =
          case key_token.type
          when :label   then key_token.value.to_sym   # render:
          when :string  then key_token.value          # "0" => ...
          when :symbol  then key_token.value.to_sym   # optional support for :foo => ...
          else
            raise_parse_error('Hash keys must be symbols (:key) or strings ("key")')
          end

        advance
        key = Kumi::Syntax::Literal.new(key_value, loc: key_token.location)

        skip_comments_and_newlines
        if current_token.type == :arrow
          advance
        else
          # Only labels may omit => (Ruby-style `key:`)
          raise_parse_error("Expected '=>' in hash pair") unless key_token.type == :label
        end

        skip_comments_and_newlines
        value = parse_expression
        [key, value]
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

      def expect_field_name_token
        token = current_token
        if token.identifier? || token.keyword?
          advance
          token.value
        else
          raise_parse_error("Expected field name (identifier or keyword), got #{token.type}")
        end
      end

      def raise_parse_error(message)
        location = current_token.location
        raise Errors::ParseError.new(message, token: current_token)
      end

      def simple_trait_reference?(condition)
        condition.is_a?(Kumi::Syntax::DeclarationReference)
      end

      def wrap_condition_in_all(condition)
        Kumi::Syntax::CallExpression.new(:cascade_and, [condition], loc: condition.loc)
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
