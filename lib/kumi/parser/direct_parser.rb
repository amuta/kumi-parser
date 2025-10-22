# frozen_string_literal: true

module Kumi
  module Parser
    # Direct AST construction parser using recursive descent with embedded token metadata
    class DirectParser
      include Kumi::Parser::Helpers

      def initialize(tokens)
        @tokens = tokens
        @pos = 0
        @imported_names = Set.new
      end

      def parse
        skip_comments_and_newlines

        # Parse root-level imports (before schema)
        root_imports = parse_imports
        @imported_names.merge(root_imports.flat_map(&:names))

        schema_node = parse_schema

        # If we have root imports, add them to the schema
        if root_imports.any?
          # Merge root imports with schema imports
          schema_node.imports.concat(root_imports)
        end

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

      # Schema: 'schema' 'do' ... 'end'
      def parse_schema
        schema_token = expect_token(:schema)
        expect_token(:do)

        skip_comments_and_newlines
        import_declarations = parse_imports
        @imported_names.merge(import_declarations.flat_map(&:names))

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
          import_declarations,
          loc: schema_token.location
        )
      end

      # Parse import declarations: 'import' :symbol, from: Module
      def parse_imports
        imports = []
        skip_comments_and_newlines

        while current_token.type == :import
          import_token = expect_token(:import)

          names = []
          names << expect_token(:symbol).value.to_sym

          while current_token.type == :comma
            expect_token(:comma)
            skip_comments_and_newlines

            # Check if this is the 'from:' keyword argument or another symbol to import
            if current_token.type == :label && current_token.value == 'from'
              # This is 'from:' - end of imports list
              break
            else
              # Another symbol to import
              names << expect_token(:symbol).value.to_sym
            end
          end

          skip_comments_and_newlines

          # Handle 'from:' keyword argument
          if current_token.type == :label && current_token.value == 'from'
            expect_token(:label) # consume 'from:'
          else
            raise_parse_error("Expected 'from:' keyword argument in import statement")
          end

          skip_comments_and_newlines

          module_ref = parse_constant

          imports << Kumi::Syntax::ImportDeclaration.new(
            names,
            module_ref,
            loc: import_token.location
          )

          skip_comments_and_newlines
        end

        imports
      end

      # Parse a constant reference like Schemas::Tax
      def parse_constant
        const_parts = []
        const_parts << expect_token(:constant).value

        while current_token.type == :colon && peek_token.type == :colon
          expect_token(:colon)
          expect_token(:colon)
          const_parts << expect_token(:constant).value
        end

        # Return the full constant path as a string that will be evaluated at runtime
        const_parts.join('::')
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

      def parse_input_declaration
        type_token = current_token
        unless type_token.metadata[:category] == :type_keyword
          raise_parse_error("Expected type keyword, got #{type_token.type}")
        end
        advance

        name_token  = expect_token(:symbol)
        actual_type = type_token.metadata[:type_name]

        domain, index_name = parse_optional_decl_kwargs

        raise_parse_error('`index:` only valid on array declarations') if index_name && actual_type != :array

        children = []
        if %i[array hash element].include?(actual_type) && current_token.type == :do
          advance
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
          actual_type,
          children,
          index_name, # <— NEW
          loc: type_token.location
        )
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
          hints: { inline: true },
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

      # Pratt parser for expressions
      def parse_expression(min_precedence = 0)
        left = parse_primary_expression
        left = parse_postfix_chain(left)
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
          left = parse_postfix_chain(left)
          skip_comments_and_newlines
        end

        left
      end

      def parse_postfix_chain(base)
        skip_comments_and_newlines
        while current_token.type == :lbracket
          expect_token(:lbracket)
          index_expr = parse_expression
          expect_token(:rbracket)
          base = Kumi::Syntax::CallExpression.new(:at, [base, index_expr], loc: base.loc)
          skip_comments_and_newlines
        end
        base
      end

      def parse_primary_expression
        token = current_token

        case token.type
        when :integer, :float, :string, :boolean, :constant, :symbol
          value = convert_literal_value(token)
          advance
          Kumi::Syntax::Literal.new(value, loc: token.location)

        when :function_sugar
          parse_function_sugar

        when :identifier
          if token.value == 'input' && peek_token.type == :dot
            parse_input_reference
          elsif token.value == 'index' && peek_token.type == :lparen
            parse_index_intrinsic
          elsif peek_token.type == :lparen
            # This is a function call like tax(amount: input.amount)
            parse_imported_function_call
          else
            advance
            Kumi::Syntax::DeclarationReference.new(token.value.to_sym, loc: token.location)
          end

        when :input
          return parse_input_reference_from_input_token if peek_token.type == :dot

          raise_parse_error("Unexpected 'input' keyword in expression")

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
          parse_function_call

        when :subtract
          advance
          skip_comments_and_newlines
          operand = parse_primary_expression
          Kumi::Syntax::CallExpression.new(:subtract, [Kumi::Syntax::Literal.new(0, loc: token.location), operand],
                                           loc: token.location)

        when :newline, :comment
          skip_comments_and_newlines
          parse_primary_expression

        else
          raise_parse_error("Unexpected token in expression: #{token.type}")
        end
      end

      def parse_index_intrinsic
        start = current_token
        if start.type == :index_type || (start.type == :identifier && start.value == 'index')
          advance
        else
          raise_parse_error('Expected index(...)')
        end

        expect_token(:lparen)
        sym = expect_token(:symbol) # :i, :j, ...
        expect_token(:rparen)
        Kumi::Syntax::IndexReference.new(sym.value, loc: start.location)
      end

      def parse_input_reference
        input_token = expect_token(:identifier) # must be 'input'
        raise_parse_error("Expected 'input'") unless input_token.value == 'input'
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

        # Check if this is an imported function call
        if @imported_names.include?(fn_name_token.value) && args.empty? && opts.any?
          # Convert to ImportCall - opts become the input mapping
          Kumi::Syntax::ImportCall.new(fn_name_token.value, opts, loc: fn_name_token.location)
        else
          # Regular call expression
          Kumi::Syntax::CallExpression.new(fn_name_token.value, args, opts, loc: fn_name_token.location)
        end
      end

      def parse_imported_function_call
        fn_name_token = current_token
        fn_name = fn_name_token.value.to_sym
        advance # consume identifier
        expect_token(:lparen)

        # Parse keyword arguments for imported function calls
        # Imported functions only accept keyword arguments
        opts = {}

        unless current_token.type == :rparen
          # Parse keyword arguments with full expression values
          while current_token.type == :label
            key = current_token.value.to_sym
            advance

            opts[key] = parse_expression

            break unless current_token.type == :comma
            advance
            skip_comments_and_newlines
          end
        end

        expect_token(:rparen)

        # Check if this is an imported function call
        if @imported_names.include?(fn_name) && opts.any?
          # Convert to ImportCall - opts become the input mapping
          Kumi::Syntax::ImportCall.new(fn_name, opts, loc: fn_name_token.location)
        else
          # Regular call expression (shouldn't happen for imported functions)
          Kumi::Syntax::CallExpression.new(fn_name, [], opts, loc: fn_name_token.location)
        end
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
    end
  end
end
