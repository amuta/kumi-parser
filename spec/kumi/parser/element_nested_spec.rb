# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Element Nested Schema Support' do
  let(:element_nested_text) do
    <<~KUMI
      schema do
        input do
          array :departments do
            string :name
            array :teams do
              string :team_name
              array :members do
                element :string, :employee_name
              end
            end
          end
        end

        value :dept_names,        input.departments.name
        value :team_names,        input.departments.teams.team_name
        value :member_arrays,     input.departments.teams.members
        value :flattened_members, fn(:flatten, input.departments.teams.members)
        value :total_members,     fn(:size, fn(:flatten, input.departments.teams.members))
      end
    KUMI
  end

  let(:element_with_children_text) do
    <<~KUMI
      schema do
        input do
          array :coordinates do
            element :array, :point do
              element :float, :axis
            end
          end
        end

        value :all_points, input.coordinates
        value :all_axes, input.coordinates.axis
      end
    KUMI
  end

  describe 'parsing element syntax' do
    it 'parses element syntax successfully' do
      expect { Kumi::Parser::TextParser.parse(element_nested_text) }.not_to raise_error
    end

    it 'validates as valid' do
      expect(Kumi::Parser::TextParser.valid?(element_nested_text)).to be true
    end

    it 'creates correct AST structure' do
      ast = Kumi::Parser::TextParser.parse(element_nested_text)
      
      # Check departments array
      departments = ast.inputs[0]
      expect(departments.name).to eq(:departments)
      expect(departments.type).to eq(:array)
      
      # Check teams array inside departments
      teams = departments.children[1]
      expect(teams.name).to eq(:teams)
      expect(teams.type).to eq(:array)
      
      # Check members array inside teams
      members = teams.children[1]
      expect(members.name).to eq(:members)
      expect(members.type).to eq(:array)
      
      # Check element inside members
      employee_name = members.children[0]
      expect(employee_name.name).to eq(:employee_name)
      expect(employee_name.type).to eq(:string)
    end
  end

  describe 'parsing element with children syntax' do
    it 'parses element with children successfully' do
      expect { Kumi::Parser::TextParser.parse(element_with_children_text) }.not_to raise_error
    end

    it 'validates as valid with children' do
      expect(Kumi::Parser::TextParser.valid?(element_with_children_text)).to be true
    end

    it 'creates correct nested structure' do
      ast = Kumi::Parser::TextParser.parse(element_with_children_text)
      
      # Check coordinates array
      coordinates = ast.inputs[0]
      expect(coordinates.name).to eq(:coordinates)
      expect(coordinates.type).to eq(:array)
      
      # Check point element inside coordinates
      point = coordinates.children[0]
      expect(point.name).to eq(:point)
      expect(point.type).to eq(:array)
      
      # Check axis element inside point
      axis = point.children[0]
      expect(axis.name).to eq(:axis)
      expect(axis.type).to eq(:float)
    end
  end

  describe 'Ruby DSL compatibility' do
    # Define equivalent Ruby DSL AST for element syntax
    module ElementNestedSchema
      extend Kumi::Schema

      build_syntax_tree do
        input do
          array :departments do
            string :name
            array :teams do
              string :team_name
              array :members do
                element :string, :employee_name
              end
            end
          end
        end

        value :dept_names,        input.departments.name
        value :team_names,        input.departments.teams.team_name
        value :member_arrays,     input.departments.teams.members
        value :flattened_members, fn(:flatten, input.departments.teams.members)
        value :total_members,     fn(:size, fn(:flatten, input.departments.teams.members))
      end
    end

    # Define equivalent Ruby DSL AST for element with children
    module ElementWithChildrenSchema
      extend Kumi::Schema

      build_syntax_tree do
        input do
          array :coordinates do
            element :array, :point do
              element :float, :axis
            end
          end
        end

        value :all_points, input.coordinates
        value :all_axes, input.coordinates.axis
      end
    end

    context 'when compared to ruby AST' do
      it 'has identical AST structure for simple elements' do
        ruby_ast = ElementNestedSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(element_nested_text)

        expect(text_ast).to eq(ruby_ast)
      end

      it 'has identical AST structure for elements with children' do
        ruby_ast = ElementWithChildrenSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(element_with_children_text)

        expect(text_ast).to eq(ruby_ast)
      end

      it 'produces identical S-expression output for simple elements' do
        ruby_ast = ElementNestedSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(element_nested_text)

        ruby_sexpr = Kumi::Support::SExpressionPrinter.print(ruby_ast)
        text_sexpr = Kumi::Support::SExpressionPrinter.print(text_ast)

        expect(text_sexpr).to eq(ruby_sexpr)
      end

      it 'produces identical S-expression output for elements with children' do
        ruby_ast = ElementWithChildrenSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(element_with_children_text)

        ruby_sexpr = Kumi::Support::SExpressionPrinter.print(ruby_ast)
        text_sexpr = Kumi::Support::SExpressionPrinter.print(text_ast)

        expect(text_sexpr).to eq(ruby_sexpr)
      end
    end
  end
end