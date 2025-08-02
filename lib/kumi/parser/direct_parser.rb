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
        while %i[value trait].include?(current_token.type)
          case current_token.type
          when :value
            value_declarations << parse_value_declaration
          when :trait
            trait_declarations << parse_trait_declaration
          end
          skip_comments_and_newlines
        end

        expect_token(:end)

        # Construct Root with exact AST.md structure
        Kumi::Syntax::Root.new(
          input_declarations,
          value_declarations, # attributes
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

      # Input declaration: 'integer :name' or 'array :items do ... end'
      def parse_input_declaration
        type_token = current_token

        if type_token.metadata[:category] != :type_keyword
          raise_parse_error("Expected type keyword, got #{type_token.type}")
        end

        advance
        name_token = expect_token(:symbol)

        # Handle domain specification: ', domain: [...]'
        domain = nil
        if current_token.type == :comma
          advance
          if current_token.type == :identifier && current_token.value == 'domain'
            advance
            expect_token(:colon)
            domain = parse_domain_specification
          else
            # Put comma back for other parsers
            @pos -= 1
          end
        end

        # Handle nested array declarations
        children = []
        if type_token.metadata[:type_name] == :array && current_token.type == :do
          advance # consume 'do'
          skip_comments_and_newlines

          until %i[end eof].include?(current_token.type)
            break unless current_token.metadata[:category] == :type_keyword

            children << parse_input_declaration

            skip_comments_and_newlines
          end

          expect_token(:end)
        end

        Kumi::Syntax::InputDeclaration.new(
          name_token.value,
          domain,
          type_token.metadata[:type_name],
          children,
          loc: type_token.location
        )
      end

      def parse_domain_specification
        # Parse domain specifications: domain: ["x", "y"], domain: [1, 2, 3], domain: 1..10, domain: 1...10
        case current_token.type
        when :lbracket
          # Array domain: ["a", "b", "c"] or [1, 2, 3]
          array_expr = parse_array_literal
          # Convert ArrayExpression to Ruby Array for analyzer compatibility
          convert_array_expression_to_ruby_array(array_expr)
        when :integer, :float
          # Range domain: 1..10 or 1...10
          parse_range_domain
        else
          # Skip unknown domain specs for now
          advance until %i[comma newline eof end].include?(current_token.type)
          nil
        end
      end

      def parse_range_domain
        # Parse numeric ranges like 1..10 or 0.0...100.0
        start_token = current_token
        start_value = start_token.type == :integer ? start_token.value.to_i : start_token.value.to_f
        advance
        
        case current_token.type
        when :dot_dot
          # Inclusive range: start..end
          advance # consume ..
          end_token = current_token
          end_value = end_token.type == :integer ? end_token.value.to_i : end_token.value.to_f
          advance
          (start_value..end_value)
        when :dot_dot_dot
          # Exclusive range: start...end
          advance # consume ...
          end_token = current_token
          end_value = end_token.type == :integer ? end_token.value.to_i : end_token.value.to_f
          advance
          (start_value...end_value)
        else
          # Just a single number, treat as single-element array
          [start_value]
        end
      end

      def convert_array_expression_to_ruby_array(array_expr)
        return nil unless array_expr.is_a?(Kumi::Syntax::ArrayExpression)
        
        array_expr.elements.map do |element|
          if element.is_a?(Kumi::Syntax::Literal)
            element.value
          else
            # For non-literal elements, we'd need more complex evaluation
            # For now, just return the element as-is
            element  
          end
        end
      end

      # Value declaration: 'value :name, expression' or 'value :name do ... end'
      def parse_value_declaration
        value_token = expect_token(:value)
        name_token = expect_token(:symbol)

        if current_token.type == :do
          # Cascade expression: value :name do ... end
          expression = parse_cascade_expression
        else
          # Simple expression: value :name, expression
          expect_token(:comma)
          expression = parse_expression
        end

        Kumi::Syntax::ValueDeclaration.new(
          name_token.value,
          expression,
          loc: value_token.location
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

      # Case expression: 'on condition, result' or 'base result'
      def parse_case_expression
        case current_token.type
        when :on
          on_token = advance_and_return_token
          condition = parse_expression
          
          # Wrap simple trait references in all? to match Ruby DSL behavior
          condition = wrap_condition_in_all(condition) if simple_trait_reference?(condition)
          
          expect_token(:comma)
          result = parse_expression

          Kumi::Syntax::CaseExpression.new(condition, result, loc: on_token.location)

        when :base
          base_token = advance_and_return_token
          result = parse_expression

          # Base case has condition = true
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

      # Expression parsing with operator precedence
      def parse_expression(min_precedence = 0)
        left = parse_primary_expression

        # Skip whitespace before checking for operators
        skip_comments_and_newlines

        while current_token.operator? && current_token.precedence >= min_precedence
          operator_token = current_token
          advance

          # Skip whitespace after operator
          skip_comments_and_newlines

          # Use embedded associativity from token metadata
          next_min_precedence = if operator_token.left_associative?
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

          # Skip whitespace before checking for next operator
          skip_comments_and_newlines
        end

        left
      end

      def parse_primary_expression
        token = current_token

        case token.type
        when :integer, :float, :string, :boolean
          # Direct AST construction using token metadata
          value = convert_literal_value(token)
          advance
          Kumi::Syntax::Literal.new(value, loc: token.location)

        when :identifier
          if token.value == 'input' && peek_token.type == :dot
            parse_input_reference
          elsif peek_token.type == :lbracket
            parse_array_access_reference
          elsif token.value == 'fn'
            parse_function_call
          else
            advance
            Kumi::Syntax::DeclarationReference.new(token.value.to_sym, loc: token.location)
          end

        when :input
          # Handle input references in expressions (input.field)
          if peek_token.type == :dot
            parse_input_reference_from_input_token
          else
            raise_parse_error("Unexpected 'input' keyword in expression")
          end

        when :lparen
          advance # consume '('
          expr = parse_expression
          expect_token(:rparen)
          expr

        when :lbracket
          parse_array_literal

        when :fn
          parse_function_call_from_fn_token

        when :newline, :comment
          # Skip newlines and comments in expressions
          skip_comments_and_newlines
          parse_primary_expression

        else
          raise_parse_error("Unexpected token in expression: #{token.type}")
        end
      end

      def parse_input_reference
        input_token = expect_token(:identifier) # 'input'
        expect_token(:dot)

        path = [expect_token(:identifier).value.to_sym]

        # Handle nested access: input.field.subfield
        while current_token.type == :dot
          advance # consume '.'
          path << expect_token(:identifier).value.to_sym
        end

        if path.length == 1
          Kumi::Syntax::InputReference.new(path.first, loc: input_token.location)
        else
          Kumi::Syntax::InputElementReference.new(path, loc: input_token.location)
        end
      end

      def parse_input_reference_from_input_token
        input_token = expect_token(:input) # 'input' keyword token
        expect_token(:dot)

        path = [expect_token(:identifier).value.to_sym]

        # Handle nested access: input.field.subfield
        while current_token.type == :dot
          advance # consume '.'
          path << expect_token(:identifier).value.to_sym
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
        Kumi::Syntax::CallExpression.new(
          :at,
          [base_ref, index_expr],
          loc: name_token.location
        )
      end

      def parse_function_call
        fn_token = expect_token(:identifier) # 'fn'

        if current_token.type == :lparen
          # Only syntax: fn(:symbol, args...)
          advance # consume '('
          fn_name_token = expect_token(:symbol)
          fn_name = fn_name_token.value

          args = []
          while current_token.type == :comma
            advance # consume comma
            args << parse_expression
          end

          expect_token(:rparen)
          Kumi::Syntax::CallExpression.new(fn_name, args, loc: fn_name_token.location)

        else
          raise_parse_error("Expected '(' after 'fn'")
        end
      end

      def parse_function_call_from_fn_token
        fn_token = expect_token(:fn) # 'fn' keyword token

        if current_token.type == :lparen
          # Only syntax: fn(:symbol, args...)
          advance # consume '('
          fn_name_token = expect_token(:symbol)
          fn_name = fn_name_token.value

          args = []
          while current_token.type == :comma
            advance # consume comma
            args << parse_expression
          end

          expect_token(:rparen)
          Kumi::Syntax::CallExpression.new(fn_name, args, loc: fn_name_token.location)

        else
          raise_parse_error("Expected '(' after 'fn'")
        end
      end

      def parse_argument_list
        args = []

        unless current_token.type == :rparen
          args << parse_expression
          while current_token.type == :comma
            advance # consume comma
            args << parse_expression
          end
        end

        args
      end

      def parse_array_literal
        start_token = expect_token(:lbracket)
        elements = []

        unless current_token.type == :rbracket
          elements << parse_expression
          while current_token.type == :comma
            advance # consume comma
            elements << parse_expression unless current_token.type == :rbracket
          end
        end

        expect_token(:rbracket)
        Kumi::Syntax::ArrayExpression.new(elements, loc: start_token.location)
      end

      def convert_literal_value(token)
        case token.type
        when :integer then token.value.gsub('_', '').to_i
        when :float then token.value.gsub('_', '').to_f
        when :string then token.value
        when :boolean then token.value == 'true'
        end
      end

      def raise_parse_error(message)
        location = current_token.location
        raise Errors::ParseError.new(message, token: current_token)
      end

      # Helper method to check if condition is a simple trait reference
      def simple_trait_reference?(condition)
        condition.is_a?(Kumi::Syntax::DeclarationReference)
      end

      # Helper method to wrap condition in all? function call
      def wrap_condition_in_all(condition)
        array_expr = Kumi::Syntax::ArrayExpression.new([condition], loc: condition.loc)
        Kumi::Syntax::CallExpression.new(:all?, [array_expr], loc: condition.loc)
      end

      # Map operator token types to function names for Ruby DSL compatibility
      def map_operator_token_to_function_name(token_type)
        case token_type
        when :eq then :==
        when :ne then :!=
        when :gt then :>
        when :lt then :<
        when :gte then :>=
        when :lte then :<=
        when :and then :and
        when :or then :or
        else token_type
        end
      end
    end
  end
end
