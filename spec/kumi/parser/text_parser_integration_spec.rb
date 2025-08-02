# frozen_string_literal: true

RSpec.describe 'Kumi::Parser::TextParser Integration' do
  describe 'diagnostic API methods' do
    let(:valid_schema) do
      <<~KUMI
        schema do
          input do
            string :name
            integer :age
          end
          value :greeting, input.name
          trait :adult, (input.age >= 18)
        end
      KUMI
    end

    let(:invalid_schema_missing_do) do
      <<~KUMI
        schema
          input do
            string :name
          end
        end
      KUMI
    end

    let(:invalid_schema_missing_end) do
      <<~KUMI
        schema do
          input do
            string :name
          end
      KUMI
    end

    let(:invalid_schema_bad_function) do
      <<~KUMI
        schema do
          input do
            string :name
          end
          value :test, fn()
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for valid schema' do
        expect(Kumi::Parser::TextParser.valid?(valid_schema)).to be true
      end

      it 'returns false for invalid schema' do
        expect(Kumi::Parser::TextParser.valid?(invalid_schema_missing_do)).to be false
        expect(Kumi::Parser::TextParser.valid?(invalid_schema_missing_end)).to be false
        expect(Kumi::Parser::TextParser.valid?(invalid_schema_bad_function)).to be false
      end

      it 'accepts custom source file parameter' do
        expect(Kumi::Parser::TextParser.valid?(valid_schema, source_file: 'test.kumi')).to be true
      end
    end

    describe '.validate' do
      it 'returns empty collection for valid schema' do
        diagnostics = Kumi::Parser::TextParser.validate(valid_schema)
        expect(diagnostics).to be_empty
        expect(diagnostics.count).to eq(0)
      end

      it 'returns diagnostics for invalid schema' do
        diagnostics = Kumi::Parser::TextParser.validate(invalid_schema_missing_do)
        expect(diagnostics.count).to eq(1)

        diagnostic = diagnostics.to_a.first
        expect(diagnostic[:line]).to be >= 1
        expect(diagnostic[:column]).to be > 0
        expect(diagnostic[:message]).to be_a(String)
        expect(diagnostic[:severity]).to eq(:error)
        expect(diagnostic[:type]).to eq(:syntax)
      end

      it 'handles multiple error types correctly' do
        [invalid_schema_missing_do, invalid_schema_missing_end, invalid_schema_bad_function].each do |schema|
          diagnostics = Kumi::Parser::TextParser.validate(schema)
          expect(diagnostics.count).to eq(1)
          expect(diagnostics.to_a.first[:severity]).to eq(:error)
        end
      end
    end
  end

  describe 'integration with analyzer and compiler' do
    let(:working_schema) do
      <<~KUMI
        schema do
          input do
            string :name
            integer :age
          end
          value :greeting, input.name
        end
      KUMI
    end

    let(:new_syntax_features) do
      <<~KUMI
        schema do
          input do
            float :income
          end
          value :deduction, 14_600
          value :array_result, [input.income, 1000]
          value :fn_result, fn(:max, [input.income, 0])
          value :indexed, some_array[0]
        end
      KUMI
    end

    it 'produces AST compatible with analyzer for simple schemas' do
      ast = Kumi::Parser::TextParser.parse(working_schema)
      
      expect(ast).to be_a(Kumi::Syntax::Root)
      expect(ast.inputs.length).to eq(2)
      expect(ast.attributes.length).to eq(1)
      
      # Should work with analyzer
      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error
      
      result = Kumi::Analyzer.analyze!(ast)
      expect(result).to be_a(Kumi::Analyzer::Result)
    end

    it 'produces AST compatible with compiler for simple schemas' do
      ast = Kumi::Parser::TextParser.parse(working_schema)
      result = Kumi::Analyzer.analyze!(ast)
      
      expect { Kumi::Compiler.compile(ast, analyzer: result) }.not_to raise_error
      
      compiled = Kumi::Compiler.compile(ast, analyzer: result)
      expect(compiled).to be_a(Kumi::Core::CompiledSchema)
    end

    it 'executes simple schemas end-to-end' do
      ast = Kumi::Parser::TextParser.parse(working_schema)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)
      
      # Test execution
      test_data = { name: "Alice", age: 25 }
      result = compiled.evaluate(test_data)
      
      expect(result.fetch(:greeting)).to eq("Alice")
    end

    it 'parses all new syntax features correctly' do
      ast = Kumi::Parser::TextParser.parse(new_syntax_features)
      
      expect(ast).to be_a(Kumi::Syntax::Root)
      expect(ast.inputs.length).to eq(1)
      expect(ast.attributes.length).to eq(4)
      
      # Verify new syntax features are parsed
      deduction = ast.attributes.find { |a| a.name == :deduction }
      expect(deduction.expression).to be_a(Kumi::Syntax::Literal)
      expect(deduction.expression.value).to eq(14600) # underscore removed
    end
  end

  describe 'integration with original parser' do
    let(:valid_for_parse) do
      <<~KUMI
        schema do
          input do
            string :name
          end
          value :greeting, input.name
        end
      KUMI
    end

    let(:invalid_for_parse) do
      <<~KUMI
        schema
          input do
            string :name
          end
        end
      KUMI
    end

    it 'maintains compatibility with parse method' do
      # Original parse method should still work
      expect { Kumi::Parser::TextParser.parse(valid_for_parse) }.not_to raise_error

      # And should produce the same AST as before
      ast = Kumi::Parser::TextParser.parse(valid_for_parse)
      expect(ast).to be_a(Kumi::Syntax::Root)
      expect(ast.inputs).not_to be_empty
      expect(ast.attributes).not_to be_empty
    end

    it 'parse method still raises errors for invalid input' do
      expect { Kumi::Parser::TextParser.parse(invalid_for_parse) }.to raise_error(Kumi::Errors::SyntaxError)
    end
  end
end
