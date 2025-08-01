# frozen_string_literal: true

require 'parslet'

module Kumi
  module Parser
    module TextParser
      # Parslet grammar with proper arithmetic operator precedence
      class Grammar < Parslet::Parser
        # Basic tokens
        rule(:space) { match('\s').repeat(1) }
        rule(:space?) { space.maybe }
        rule(:newline?) { match('\n').maybe }

        # Comments
        rule(:comment) { str('#') >> match('[^\n]').repeat }
        rule(:ws) { (space | comment).repeat }
        rule(:ws?) { ws.maybe }

        # Identifiers and symbols
        rule(:identifier) { match('[a-zA-Z_]') >> match('[a-zA-Z0-9_]').repeat }
        rule(:symbol) { str(':') >> identifier.as(:symbol) }

        # Literals (with underscore support for readability)
        rule(:integer_part) { match('[0-9]') >> (str('_').maybe >> match('[0-9]')).repeat }
        rule(:integer) { integer_part }
        rule(:float) { integer >> str('.') >> integer_part }
        rule(:number) { float.as(:float) | integer.as(:integer) }
        rule(:string_literal) do
          str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"')
        end
        rule(:boolean) { (str('true').as(:true) | str('false').as(:false)) }
        rule(:array_literal) do
          str('[') >> ws? >>
            (expression >> (ws? >> str(',') >> ws? >> expression).repeat).maybe.as(:elements) >>
            ws? >> str(']')
        end
        rule(:literal) { array_literal.as(:array) | number | string_literal | boolean }

        # Keywords
        rule(:schema_kw) { str('schema') }
        rule(:input_kw) { str('input') }
        rule(:value_kw) { str('value') }
        rule(:trait_kw) { str('trait') }
        rule(:do_kw) { str('do') }
        rule(:end_kw) { str('end') }

        # Type keywords
        rule(:type_name) do
          str('integer') | str('float') | str('string') | str('boolean') | str('any')
        end

        # Operators (ordered by precedence, highest to lowest)
        rule(:mult_op) { str('*').as(:multiply) | str('/').as(:divide) | str('%').as(:modulo) }
        rule(:add_op) { str('+').as(:add) | str('-').as(:subtract) }
        rule(:comp_op) do
          str('>=').as(:>=) | str('<=').as(:<=) | str('==').as(:==) |
            str('!=').as(:!=) | str('>').as(:>) | str('<').as(:<)
        end
        rule(:logical_and_op) { str('&').as(:and) }
        rule(:logical_or_op) { str('|').as(:or) }

        # Expressions with proper precedence (using left recursion elimination)
        rule(:primary_expr) do
          str('(') >> ws? >> expression >> ws? >> str(')') |
            function_call |
            input_reference |
            declaration_reference |
            literal
        end

        # Function calls: fn(:name, arg1, arg2, ...) or fn.name(arg1, arg2, ...)
        rule(:function_call) do
          classic_function_call | dot_function_call
        end

        rule(:classic_function_call) do
          str('fn(') >> ws? >>
            symbol.as(:fn_name) >>
            (str(',') >> ws? >> expression).repeat(0).as(:args) >>
            ws? >> str(')')
        end

        rule(:dot_function_call) do
          str('fn.') >> identifier.as(:fn_name) >> str('(') >> ws? >>
            (expression >> (ws? >> str(',') >> ws? >> expression).repeat).maybe.as(:args) >>
            ws? >> str(')')
        end

        # Multiplication/Division (left-associative)
        rule(:mult_expr) do
          primary_expr.as(:left) >>
            (space? >> mult_op.as(:op) >> space? >> primary_expr.as(:right)).repeat.as(:ops)
        end

        # Addition/Subtraction (left-associative)
        rule(:add_expr) do
          mult_expr.as(:left) >>
            (space? >> add_op.as(:op) >> space? >> mult_expr.as(:right)).repeat.as(:ops)
        end

        # Comparison operators
        rule(:comp_expr) do
          add_expr.as(:left) >>
            (space? >> comp_op.as(:op) >> space? >> add_expr.as(:right)).maybe.as(:comp)
        end

        # Logical AND (higher precedence than OR)
        rule(:logical_and_expr) do
          comp_expr.as(:left) >>
            (space? >> logical_and_op.as(:op) >> space? >> comp_expr.as(:right)).repeat.as(:ops)
        end

        # Logical OR (lowest precedence)
        rule(:logical_or_expr) do
          logical_and_expr.as(:left) >>
            (space? >> logical_or_op.as(:op) >> space? >> logical_and_expr.as(:right)).repeat.as(:ops)
        end

        rule(:expression) { logical_or_expr }

        # Input references: input.field or input.field.subfield
        rule(:input_reference) do
          str('input.') >> input_path.as(:input_ref)
        end

        rule(:input_path) do
          identifier >> (str('.') >> identifier).repeat
        end

        # Declaration references: identifier or identifier[index]
        rule(:declaration_reference) do
          array_access_reference | simple_declaration_reference
        end

        rule(:simple_declaration_reference) do
          identifier.as(:decl_ref)
        end

        rule(:array_access_reference) do
          identifier.as(:array_name) >> str('[') >> ws? >> 
            integer.as(:index) >> ws? >> str(']')
        end

        # Input declarations
        rule(:input_declaration) do
          nested_array_declaration | simple_input_declaration
        end

        rule(:simple_input_declaration) do
          ws? >> type_name.as(:type) >> space >> symbol.as(:name) >>
            (str(',') >> ws? >> domain_spec).maybe.as(:domain) >> ws? >> newline?
        end

        rule(:nested_array_declaration) do
          ws? >> str('array') >> space >> symbol.as(:name) >> space >> do_kw >> ws? >> newline? >>
            (ws? >> input_declaration >> ws?).repeat.as(:nested_fields) >>
            ws? >> end_kw >> ws? >> newline?
        end

        rule(:domain_spec) do
          str('domain:') >> ws? >> domain_value.as(:domain_value)
        end

        rule(:domain_value) do
          # Ranges: 1..10, 1...10, 0.0..100.0
          range_value |
            # Word arrays: %w[active inactive]
            word_array_value |
            # String arrays: ["active", "inactive"]
            string_array_value
        end

        rule(:range_value) do
          (float | integer) >> str('..') >> (float | integer)
        end

        rule(:word_array_value) do
          str('%w[') >> (identifier >> space?).repeat.as(:words) >> str(']')
        end

        rule(:string_array_value) do
          str('[') >> space? >>
            (string_literal >> (str(',') >> space? >> string_literal).repeat).maybe >>
            space? >> str(']')
        end

        # Value declarations
        rule(:value_declaration) do
          cascade_value_declaration | simple_value_declaration
        end

        rule(:simple_value_declaration) do
          ws? >> value_kw.as(:type) >> space >> symbol.as(:name) >> str(',') >> ws? >>
            expression.as(:expr) >> ws? >> newline?
        end

        rule(:cascade_value_declaration) do
          ws? >> value_kw.as(:type) >> space >> symbol.as(:name) >> space >> do_kw >> ws? >> newline? >>
            (ws? >> cascade_case >> ws?).repeat.as(:cases) >>
            ws? >> end_kw >> ws? >> newline?
        end

        rule(:cascade_case) do
          (ws? >> str('on') >> space >> identifier.as(:condition) >> str(',') >> ws? >>
           expression.as(:result) >> ws? >> newline?) |
            (ws? >> str('base') >> space >> expression.as(:base_result) >> ws? >> newline?)
        end

        # Trait declarations
        rule(:trait_declaration) do
          ws? >> trait_kw.as(:type) >> space >> symbol.as(:name) >> str(',') >> ws? >>
            expression.as(:expr) >> ws? >> newline?
        end

        # Input block
        rule(:input_block) do
          ws? >> input_kw >> space >> do_kw >> ws? >> newline? >>
            (ws? >> input_declaration >> ws?).repeat.as(:declarations) >>
            ws? >> end_kw >> ws? >> newline?
        end

        # Schema structure
        rule(:schema_body) do
          input_block.as(:input) >>
            (ws? >> (value_declaration | trait_declaration) >> ws?).repeat.as(:declarations)
        end

        rule(:schema) do
          ws? >> schema_kw >> space >> do_kw >> ws? >> newline? >>
            schema_body >>
            ws? >> end_kw >> ws?
        end

        root(:schema)
      end
    end
  end
end
