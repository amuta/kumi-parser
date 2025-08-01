# frozen_string_literal: true

require 'parslet'
require 'kumi/syntax/node'
require 'kumi/syntax/root'
require 'kumi/syntax/input_declaration'
require 'kumi/syntax/value_declaration'
require 'kumi/syntax/trait_declaration'
require 'kumi/syntax/call_expression'
require 'kumi/syntax/input_reference'
require 'kumi/syntax/input_element_reference'
require 'kumi/syntax/declaration_reference'
require 'kumi/syntax/literal'

module Kumi
  module Parser
    module TextParser
      class Transform < Parslet::Transform
        LOC = Kumi::Syntax::Location.new(file: '<parslet_parser>', line: 1, column: 1)

        # Literals
        rule(integer: simple(:x)) { Kumi::Syntax::Literal.new(x.to_i, loc: LOC) }
        rule(float: simple(:x)) { Kumi::Syntax::Literal.new(x.to_f, loc: LOC) }
        rule(string: simple(:x)) { Kumi::Syntax::Literal.new(x.to_s, loc: LOC) }
        rule(true: simple(:_)) { Kumi::Syntax::Literal.new(true, loc: LOC) }
        rule(false: simple(:_)) { Kumi::Syntax::Literal.new(false, loc: LOC) }

        # Symbols
        rule(symbol: simple(:name)) { name.to_sym }

        # Input and declaration references
        rule(input_ref: simple(:path)) do
          # Handle multi-level paths like "items.price"
          path_parts = path.to_s.split('.')
          if path_parts.length == 1
            Kumi::Syntax::InputReference.new(path_parts[0].to_sym, loc: LOC)
          else
            Kumi::Syntax::InputElementReference.new(path_parts.map(&:to_sym), loc: LOC)
          end
        end

        rule(decl_ref: simple(:name)) { Kumi::Syntax::DeclarationReference.new(name.to_sym, loc: LOC) }

        # Function calls
        rule(fn_name: simple(:name), args: sequence(:args)) do
          Kumi::Syntax::CallExpression.new(name, args, loc: LOC)
        end

        rule(fn_name: simple(:name), args: []) do
          Kumi::Syntax::CallExpression.new(name, [], loc: LOC)
        end

        # Arithmetic expressions with left-associativity
        rule(left: simple(:l), ops: sequence(:operations)) do
          operations.inject(l) do |left_expr, op|
            op_name = op[:op].keys.first
            Kumi::Syntax::CallExpression.new(op_name, [left_expr, op[:right]], loc: LOC)
          end
        end

        rule(left: simple(:l), ops: []) { l }

        # Comparison expressions
        rule(left: simple(:l), comp: simple(:comparison)) do
          if comparison && comparison[:op] && comparison[:right]
            op_name = comparison[:op].keys.first
            Kumi::Syntax::CallExpression.new(op_name, [l, comparison[:right]], loc: LOC)
          else
            l
          end
        end

        rule(left: simple(:l), comp: nil) { l }

        # Simple input declarations
        rule(type: simple(:type), name: simple(:name)) do
          Kumi::Syntax::InputDeclaration.new(name, nil, type.to_sym, [], loc: LOC)
        end

        # Nested array declarations
        rule(name: simple(:name), nested_fields: sequence(:fields)) do
          # Transform nested field hashes to InputDeclaration objects
          transformed_fields = fields.map do |field|
            if field.is_a?(Hash) && field[:type] && field[:name]
              Kumi::Syntax::InputDeclaration.new(
                field[:name],
                field[:domain],
                field[:type].to_sym,
                [],
                loc: LOC
              )
            else
              field
            end
          end

          # Create an array input declaration with nested fields
          Kumi::Syntax::InputDeclaration.new(
            name,
            nil,
            :array,
            transformed_fields,
            loc: LOC
          )
        end

        rule(name: simple(:name), nested_fields: simple(:field)) do
          # Single nested field case
          transformed_field = if field.is_a?(Hash) && field[:type] && field[:name]
                                Kumi::Syntax::InputDeclaration.new(
                                  field[:name],
                                  field[:domain],
                                  field[:type].to_sym,
                                  [],
                                  loc: LOC
                                )
                              else
                                field
                              end

          Kumi::Syntax::InputDeclaration.new(
            name,
            nil,
            :array,
            [transformed_field],
            loc: LOC
          )
        end

        rule(type: simple(:type), name: simple(:name), expr: simple(:expr)) do
          # Differentiate between value and trait declarations based on type
          if type.to_s == 'value'
            Kumi::Syntax::ValueDeclaration.new(name, expr, loc: LOC)
          elsif type.to_s == 'trait'
            Kumi::Syntax::TraitDeclaration.new(name, expr, loc: LOC)
          else
            # Fallback - shouldn't happen
            Kumi::Syntax::ValueDeclaration.new(name, expr, loc: LOC)
          end
        end

        # Handle the intermediate case before the expression gets fully transformed
        rule(type: simple(:type), name: { symbol: simple(:name) }, expr: simple(:expr)) do
          # Differentiate between value and trait declarations based on type
          if type.to_s == 'value'
            Kumi::Syntax::ValueDeclaration.new(name.to_sym, expr, loc: LOC)
          elsif type.to_s == 'trait'
            Kumi::Syntax::TraitDeclaration.new(name.to_sym, expr, loc: LOC)
          else
            # Fallback - shouldn't happen
            Kumi::Syntax::ValueDeclaration.new(name.to_sym, expr, loc: LOC)
          end
        end

        # Schema structure - convert the hash to Root node
        rule(input: { declarations: sequence(:input_decls) }, declarations: sequence(:other_decls)) do
          values = other_decls.select { |d| d.is_a?(Kumi::Syntax::ValueDeclaration) }
          traits = other_decls.select { |d| d.is_a?(Kumi::Syntax::TraitDeclaration) }
          Kumi::Syntax::Root.new(input_decls, values, traits, loc: LOC)
        end

        rule(input: { declarations: simple(:input_decl) }, declarations: sequence(:other_decls)) do
          values = other_decls.select { |d| d.is_a?(Kumi::Syntax::ValueDeclaration) }
          traits = other_decls.select { |d| d.is_a?(Kumi::Syntax::TraitDeclaration) }
          Kumi::Syntax::Root.new([input_decl], values, traits, loc: LOC)
        end
      end
    end
  end
end
