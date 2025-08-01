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
        rule(integer: simple(:x)) { Kumi::Syntax::Literal.new(x.to_s.gsub('_', '').to_i, loc: LOC) }
        rule(float: simple(:x)) { Kumi::Syntax::Literal.new(x.to_s.gsub('_', '').to_f, loc: LOC) }
        rule(string: simple(:x)) { Kumi::Syntax::Literal.new(x.to_s, loc: LOC) }
        rule(true: simple(:_)) { Kumi::Syntax::Literal.new(true, loc: LOC) }
        rule(false: simple(:_)) { Kumi::Syntax::Literal.new(false, loc: LOC) }

        # Array literals
        rule(array: { elements: sequence(:elements) }) do
          Kumi::Syntax::Literal.new(elements, loc: LOC)
        end

        rule(array: { elements: simple(:element) }) do
          Kumi::Syntax::Literal.new([element], loc: LOC)
        end

        rule(array: { elements: nil }) do
          Kumi::Syntax::Literal.new([], loc: LOC)
        end

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

        # Array access: array_name[index]
        rule(array_name: simple(:name), index: simple(:idx)) do
          index_literal = Kumi::Syntax::Literal.new(idx.to_s.gsub('_', '').to_i, loc: LOC)
          base_ref = Kumi::Syntax::DeclarationReference.new(name.to_sym, loc: LOC)
          Kumi::Syntax::CallExpression.new(:[], [base_ref, index_literal], loc: LOC)
        end

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

        # Handle expressions with no operations and no comparison
        rule(left: simple(:l), ops: [], comp: nil) { l }

        # Handle nested expression structures (when transform creates nested left/ops/comp)
        rule(left: subtree(:nested), ops: [], comp: nil) do
          # If the nested part is also a left/ops/comp structure, process it
          if nested.is_a?(Hash) && nested[:left] && nested[:ops] && nested[:comp]
            # Process the nested structure recursively
            process_nested_expression(nested)
          else
            nested
          end
        end

        # CRITICAL: Every node in the schema tree must be a proper AST node with children method
        # The schema tree structure is: AST -> children -> children (recursive)
        # Hash objects break the analyzer because they don't have the children method
        # This method converts nested Hash structures from grammar into proper AST nodes
        def self.process_nested_expression(expr)
          return expr unless expr.is_a?(Hash)
          
          # Handle {:left, :ops, :comp} structure (comparison expressions)
          if expr[:left] && expr.has_key?(:ops) && expr.has_key?(:comp)
            left = expr[:left]
            left = process_nested_expression(left) if left.is_a?(Hash)
            
            ops = expr[:ops] || []
            ops = [ops] unless ops.is_a?(Array)
            
            result = ops.inject(left) do |left_expr, op|
              if op.is_a?(Hash) && op[:op] && op[:right]
                op_name = op[:op].keys.first
                right_expr = process_nested_expression(op[:right])
                Kumi::Syntax::CallExpression.new(op_name, [left_expr, right_expr], loc: LOC)
              else
                left_expr
              end
            end
            
            # Handle comparison
            if expr[:comp] && !expr[:comp].nil?
              comp = expr[:comp]
              if comp.is_a?(Hash) && comp[:op] && comp[:right]
                op_name = comp[:op].keys.first
                right_expr = process_nested_expression(comp[:right])
                Kumi::Syntax::CallExpression.new(op_name, [result, right_expr], loc: LOC)
              else
                result
              end
            else
              result
            end
          # Handle {:left, :ops} structure (without comp)
          elsif expr[:left] && expr.has_key?(:ops) && !expr.has_key?(:comp)
            left = expr[:left]
            left = process_nested_expression(left) if left.is_a?(Hash)
            
            ops = expr[:ops] || []
            ops = [ops] unless ops.is_a?(Array)
            
            ops.inject(left) do |left_expr, op|
              if op.is_a?(Hash) && op[:op] && op[:right]
                op_name = op[:op].keys.first
                right_expr = process_nested_expression(op[:right])
                Kumi::Syntax::CallExpression.new(op_name, [left_expr, right_expr], loc: LOC)
              else
                left_expr
              end
            end
          else
            expr
          end
        end

        # Comparison expressions - handle both Hash and simple cases
        rule(left: simple(:l), comp: simple(:comparison)) do
          if comparison && comparison.is_a?(Hash) && comparison[:op] && comparison[:right]
            op_name = comparison[:op].keys.first
            Kumi::Syntax::CallExpression.new(op_name, [l, comparison[:right]], loc: LOC)
          else
            l
          end
        end

        rule(left: simple(:l), comp: subtree(:comparison)) do
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

        # Handle the case with subtree expressions (complex nested expressions)  
        rule(type: simple(:type), name: { symbol: simple(:name) }, expr: subtree(:expr)) do
          # Process the expression to convert nested Hash structures to AST nodes
          processed_expr = Transform.process_nested_expression(expr)
          
          # Differentiate between value and trait declarations based on type
          if type.to_s == 'value'
            Kumi::Syntax::ValueDeclaration.new(name.to_sym, processed_expr, loc: LOC)
          elsif type.to_s == 'trait'
            Kumi::Syntax::TraitDeclaration.new(name.to_sym, processed_expr, loc: LOC)
          else
            # Fallback - shouldn't happen
            Kumi::Syntax::ValueDeclaration.new(name.to_sym, processed_expr, loc: LOC)
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
