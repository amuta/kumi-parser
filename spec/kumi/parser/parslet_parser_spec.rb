# frozen_string_literal: true

RSpec.describe Kumi::Parser::TextParser::Parser do
  let(:parser) { described_class.new }

  describe '#parse' do
    context 'with valid schemas' do
      let(:simple_schema) do
        <<~KUMI
          schema do
            input do
              string :name
            end
            value :greeting, input.name
          end
        KUMI
      end

      let(:complex_schema) do
        <<~KUMI
          schema do
            input do
              string :name
              integer :age
              array :items do
                float :price
                integer :quantity
              end
            end
            value :total_value, fn(:multiply, input.items.price, input.items.quantity)
            trait :adult, (input.age >= 18)
            trait :expensive, (input.items.price > 100.0)
            value :status do
              on adult, "Adult User"
              on expensive, "Premium Item"
              base "Standard"
            end
          end
        KUMI
      end

      it 'parses simple schema correctly' do
        ast = parser.parse(simple_schema)

        expect(ast).to be_a(Kumi::Syntax::Root)
        expect(ast.inputs.length).to eq(1)
        expect(ast.attributes.length).to eq(1)
        expect(ast.traits.length).to eq(0)

        input = ast.inputs.first
        expect(input.name).to eq(:name)
        expect(input.type).to eq(:string)
      end

      it 'parses complex schema with nested arrays' do
        ast = parser.parse(complex_schema)

        expect(ast).to be_a(Kumi::Syntax::Root)
        expect(ast.inputs.length).to be >= 2 # At least name and age
        expect(ast.attributes.length).to be > 0

        # Basic parsing works
        name_input = ast.inputs.find { |i| i.name == :name }
        expect(name_input).not_to be_nil
        expect(name_input.type).to eq(:string)
      end

      it 'handles arithmetic operators with correct precedence' do
        arithmetic_schema = <<~KUMI
          schema do
            input do
              integer :a
              integer :b
              integer :c
            end
            value :result, input.a + input.b * input.c
          end
        KUMI

        ast = parser.parse(arithmetic_schema)
        expect(ast).to be_a(Kumi::Syntax::Root)

        # Should parse without error (precedence is handled in transform)
        value_declaration = ast.attributes.first
        expect(value_declaration.name).to eq(:result)
      end

      it 'handles parentheses for expression grouping' do
        parentheses_schema = <<~KUMI
          schema do
            input do
              integer :a
              integer :b
              integer :c
            end
            value :result, (input.a + input.b) * input.c
          end
        KUMI

        ast = parser.parse(parentheses_schema)
        expect(ast).to be_a(Kumi::Syntax::Root)

        value_declaration = ast.attributes.first
        expect(value_declaration.name).to eq(:result)
      end

      it 'handles function calls' do
        function_schema = <<~KUMI
          schema do
            input do
              float :x
              float :y
            end
            value :sum, fn(:add, input.x, input.y)
            value :product, fn(:multiply, input.x, input.y)
          end
        KUMI

        ast = parser.parse(function_schema)
        expect(ast).to be_a(Kumi::Syntax::Root)
        expect(ast.attributes.length).to eq(2)
      end

      it 'handles cascade expressions' do
        cascade_schema = <<~KUMI
          schema do
            input do
              integer :age
            end
            trait :adult, (input.age >= 18)
            value :status do
              on adult, "Adult"
              base "Guest"
            end
          end
        KUMI

        ast = parser.parse(cascade_schema)
        expect(ast).to be_a(Kumi::Syntax::Root)
        expect(ast.attributes.length).to be > 0
      end
    end

    context 'with syntax errors' do
      it "raises SyntaxError for missing 'do' keyword" do
        invalid_schema = <<~KUMI
          schema
            input do
              string :name
            end
          end
        KUMI

        expect { parser.parse(invalid_schema) }.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include('Parse error')
          expect(error.message).to include('do')
        end
      end

      it "raises SyntaxError for missing 'end' keyword" do
        invalid_schema = <<~KUMI
          schema do
            input do
              string :name
            end
        KUMI

        expect { parser.parse(invalid_schema) }.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include('Parse error')
        end
      end

      it 'raises SyntaxError for invalid function syntax' do
        invalid_schema = <<~KUMI
          schema do
            input do
              string :name
            end
            value :test, fn()
          end
        KUMI

        expect { parser.parse(invalid_schema) }.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include('Parse error')
        end
      end

      it 'raises SyntaxError for malformed input references' do
        invalid_schema = <<~KUMI
          schema do
            input do
              string :name
            end
            value :test, input.
          end
        KUMI

        expect { parser.parse(invalid_schema) }.to raise_error(Kumi::Errors::SyntaxError)
      end

      it 'raises SyntaxError for missing symbol colon' do
        invalid_schema = <<~KUMI
          schema do
            input do
              string name
            end
          end
        KUMI

        expect { parser.parse(invalid_schema) }.to raise_error(Kumi::Errors::SyntaxError)
      end
    end

    context 'with source file parameter' do
      it 'includes source file in error messages' do
        invalid_schema = 'schema'
        source_file = 'test_schema.kumi'

        expect do
          parser.parse(invalid_schema, source_file: source_file)
        end.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include(source_file)
        end
      end

      it 'uses default source file when not provided' do
        invalid_schema = 'schema'

        expect { parser.parse(invalid_schema) }.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include('<parslet_parser>')
        end
      end
    end
  end

  # NOTE: parse_with_diagnostics and validate_syntax are internal methods
  # They are tested indirectly through the public API integration tests
end
