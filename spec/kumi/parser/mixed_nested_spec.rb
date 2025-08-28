# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mixed Nested Schema Support' do
  let(:mixed_nested_text) { File.read('spec/fixtures/mixed_nested.rb') }

  describe 'parsing mixed nested hash/array structures' do
    it 'parses successfully' do
      expect { Kumi::Parser::TextParser.parse(mixed_nested_text) }.not_to raise_error
    end

    it 'creates correct AST structure with deep nesting' do
      ast = Kumi::Parser::TextParser.parse(mixed_nested_text)

      # Verify top-level structure
      expect(ast.inputs.length).to eq(1)

      # Verify organization structure (hash with nested children)
      organization = ast.inputs[0]
      expect(organization.name).to eq(:organization)
      expect(organization.type).to eq(:hash)
      expect(organization.children.length).to eq(2)

      # Verify name field (simple string)
      name_field = organization.children[0]
      expect(name_field.name).to eq(:name)
      expect(name_field.type).to eq(:string)
      expect(name_field.children).to be_empty

      # Verify regions field (array with nested children)
      regions_field = organization.children[1]
      expect(regions_field.name).to eq(:regions)
      expect(regions_field.type).to eq(:array)
      expect(regions_field.children.length).to eq(2)

      # Verify region_name field
      region_name_field = regions_field.children[0]
      expect(region_name_field.name).to eq(:region_name)
      expect(region_name_field.type).to eq(:string)

      # Verify headquarters field (nested hash)
      headquarters_field = regions_field.children[1]
      expect(headquarters_field.name).to eq(:headquarters)
      expect(headquarters_field.type).to eq(:hash)
      expect(headquarters_field.children.length).to eq(2)

      # Verify deep nesting continues (buildings -> facilities)
      buildings_field = headquarters_field.children[1]
      expect(buildings_field.name).to eq(:buildings)
      expect(buildings_field.type).to eq(:array)

      facilities_field = buildings_field.children[1]
      expect(facilities_field.name).to eq(:facilities)
      expect(facilities_field.type).to eq(:hash)
      expect(facilities_field.children.length).to eq(3)
    end

    it 'validates successfully' do
      expect(Kumi::Parser::TextParser.valid?(mixed_nested_text)).to be true
    end
  end

  describe 'Ruby DSL compatibility' do
    # Define equivalent Ruby DSL AST
    module MixedNestedSchema
      extend Kumi::Schema

      build_syntax_tree do
        input do
          hash :organization do
            string :name
            array :regions do
              string :region_name
              hash :headquarters do
                string :city
                array :buildings do
                  string :building_name
                  hash :facilities do
                    string :facility_type
                    integer :capacity
                    float :utilization_rate
                  end
                end
              end
            end
          end
        end

        # Deep access across 5 levels
        value :org_name, input.organization.name
        value :region_names, input.organization.regions.region_name
        value :hq_cities, input.organization.regions.headquarters.city
        value :building_names, input.organization.regions.headquarters.buildings.building_name
        value :facility_types, input.organization.regions.headquarters.buildings.facilities.facility_type
        value :capacities, input.organization.regions.headquarters.buildings.facilities.capacity
        value :utilization_rates, input.organization.regions.headquarters.buildings.facilities.utilization_rate

        # Traits using deep nesting
        trait :large_organization, fn(:size, input.organization.regions) > 1

        # Simple cascade using traits
        value :org_classification do
          on large_organization, 'Enterprise'
          base 'Standard'
        end

        # Aggregations
        value :total_capacity, fn(:sum, input.organization.regions.headquarters.buildings.facilities.capacity)
      end
    end

    context 'when compared to ruby AST' do
      it 'has identical AST structure' do
        ruby_ast = MixedNestedSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(mixed_nested_text)

        # Direct AST comparison
        expect(text_ast).to eq(ruby_ast)
      end

      it 'produces identical S-expression output' do
        ruby_ast = MixedNestedSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(mixed_nested_text)

        ruby_sexpr = Kumi::Support::SExpressionPrinter.print(ruby_ast)
        text_sexpr = Kumi::Support::SExpressionPrinter.print(text_ast)

        expect(text_sexpr).to eq(ruby_sexpr)
      end
    end
  end
end
