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
        expect(diagnostic.line).to be > 1
        expect(diagnostic.column).to be > 0
        expect(diagnostic.message).to be_a(String)
        expect(diagnostic.severity).to eq(:error)
        expect(diagnostic.type).to eq(:syntax)
      end

      it 'handles multiple error types correctly' do
        [invalid_schema_missing_do, invalid_schema_missing_end, invalid_schema_bad_function].each do |schema|
          diagnostics = Kumi::Parser::TextParser.validate(schema)
          expect(diagnostics.count).to eq(1)
          expect(diagnostics.to_a.first.severity).to eq(:error)
        end
      end
    end

    describe '.diagnostics_for_monaco' do
      it 'returns empty array for valid schema' do
        result = Kumi::Parser::TextParser.diagnostics_for_monaco(valid_schema)
        expect(result).to eq([])
      end

      it 'returns Monaco format for invalid schema' do
        result = Kumi::Parser::TextParser.diagnostics_for_monaco(invalid_schema_missing_do)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        diagnostic = result.first
        expect(diagnostic).to have_key(:severity)
        expect(diagnostic).to have_key(:message)
        expect(diagnostic).to have_key(:startLineNumber)
        expect(diagnostic).to have_key(:startColumn)
        expect(diagnostic).to have_key(:endLineNumber)
        expect(diagnostic).to have_key(:endColumn)

        expect(diagnostic[:severity]).to eq(8) # Monaco.MarkerSeverity.Error
        expect(diagnostic[:startLineNumber]).to be > 1
        expect(diagnostic[:startColumn]).to be > 0
      end

      it 'handles complex errors with proper line/column info' do
        result = Kumi::Parser::TextParser.diagnostics_for_monaco(invalid_schema_bad_function)

        diagnostic = result.first
        expect(diagnostic[:startLineNumber]).to eq(5) # Line with fn()
        expect(diagnostic[:message]).to include('end')
      end
    end

    describe '.diagnostics_for_codemirror' do
      it 'returns empty array for valid schema' do
        result = Kumi::Parser::TextParser.diagnostics_for_codemirror(valid_schema)
        expect(result).to eq([])
      end

      it 'returns CodeMirror format for invalid schema' do
        result = Kumi::Parser::TextParser.diagnostics_for_codemirror(invalid_schema_missing_do)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        diagnostic = result.first
        expect(diagnostic).to have_key(:from)
        expect(diagnostic).to have_key(:to)
        expect(diagnostic).to have_key(:severity)
        expect(diagnostic).to have_key(:message)

        expect(diagnostic[:severity]).to eq('error')
        expect(diagnostic[:from]).to be_a(Integer)
        expect(diagnostic[:to]).to be_a(Integer)
        expect(diagnostic[:to]).to be > diagnostic[:from]
      end
    end

    describe '.diagnostics_as_json' do
      it 'returns empty JSON array for valid schema' do
        result = Kumi::Parser::TextParser.diagnostics_as_json(valid_schema)
        parsed = JSON.parse(result)
        expect(parsed).to eq([])
      end

      it 'returns valid JSON for invalid schema' do
        result = Kumi::Parser::TextParser.diagnostics_as_json(invalid_schema_missing_do)

        expect(result).to be_a(String)
        parsed = JSON.parse(result)

        expect(parsed).to be_an(Array)
        expect(parsed.length).to eq(1)

        diagnostic = parsed.first
        expect(diagnostic).to have_key('line')
        expect(diagnostic).to have_key('column')
        expect(diagnostic).to have_key('message')
        expect(diagnostic).to have_key('severity')
        expect(diagnostic).to have_key('type')

        expect(diagnostic['severity']).to eq('error')
        expect(diagnostic['type']).to eq('syntax')
        expect(diagnostic['line']).to be > 1
        expect(diagnostic['column']).to be > 0
      end

      it 'produces consistent JSON structure across different errors' do
        test_schemas = [invalid_schema_missing_do, invalid_schema_missing_end, invalid_schema_bad_function]

        test_schemas.each do |schema|
          result = Kumi::Parser::TextParser.diagnostics_as_json(schema)
          parsed = JSON.parse(result)

          expect(parsed.length).to eq(1)
          diagnostic = parsed.first

          # All diagnostics should have the same structure
          %w[line column message severity type].each do |key|
            expect(diagnostic).to have_key(key)
          end
        end
      end
    end

    describe 'source file parameter handling' do
      it 'passes source file to all diagnostic methods' do
        source_file = 'user_schema.kumi'

        # These shouldn't raise errors and should accept the parameter
        expect { Kumi::Parser::TextParser.valid?(valid_schema, source_file: source_file) }.not_to raise_error
        expect { Kumi::Parser::TextParser.validate(valid_schema, source_file: source_file) }.not_to raise_error
        expect do
          Kumi::Parser::TextParser.diagnostics_for_monaco(valid_schema, source_file: source_file)
        end.not_to raise_error
        expect do
          Kumi::Parser::TextParser.diagnostics_for_codemirror(valid_schema, source_file: source_file)
        end.not_to raise_error
        expect do
          Kumi::Parser::TextParser.diagnostics_as_json(valid_schema, source_file: source_file)
        end.not_to raise_error
      end
    end

    describe 'error message quality' do
      it 'produces human-readable error messages' do
        diagnostics = Kumi::Parser::TextParser.validate(invalid_schema_missing_do)
        message = diagnostics.to_a.first.message

        # Should be humanized, not raw parser output
        expect(message).not_to include('Failed to match sequence')
        expect(message).not_to include('SPACE?')
        expect(message).not_to include('`-')

        # Should contain helpful information
        expect(message.downcase).to include('do')
      end

      it 'provides specific error messages for different error types' do
        test_cases = [
          [invalid_schema_missing_do, 'do'],
          [invalid_schema_missing_end, 'end'],
          [invalid_schema_bad_function, 'end'] # fn() causes end expectation
        ]

        test_cases.each do |schema, expected_keyword|
          diagnostics = Kumi::Parser::TextParser.validate(schema)
          message = diagnostics.to_a.first.message.downcase
          expect(message).to include(expected_keyword)
        end
      end
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
