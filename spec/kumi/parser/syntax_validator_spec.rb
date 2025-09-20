# frozen_string_literal: true

RSpec.describe Kumi::Parser::SyntaxValidator do
  let(:validator) { described_class.new }

  describe '#validate' do
    context 'with valid schema' do
      let(:valid_schema) do
        <<~KUMI
          # comment Line
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

      it 'returns empty diagnostics collection' do
        diagnostics = validator.validate(valid_schema)
        expect(diagnostics).to be_empty
        expect(diagnostics.count).to eq(0)
      end
    end

    context 'with syntax errors' do
      let(:missing_do_schema) do
        <<~KUMI
          schema
            input do
              string :name
            end
          end
        KUMI
      end

      it 'extracts error with correct line and column' do
        diagnostics = validator.validate(missing_do_schema)

        expect(diagnostics.count).to eq(1)

        error = diagnostics.to_a.first
        expect(error[:line]).to eq(1)
        expect(error[:column]).to eq(7)
        expect(error[:severity]).to eq(:error)
        expect(error[:type]).to eq(:syntax)
        expect(error[:message]).to include('do')
      end
    end

    context 'with missing end keyword' do
      let(:missing_end_schema) do
        <<~KUMI
          schema do
            input do
              string :name
            end
        KUMI
      end

      it 'detects missing end at correct location' do
        diagnostics = validator.validate(missing_end_schema)

        expect(diagnostics.count).to eq(1)
        error = diagnostics.to_a.first
        expect(error[:line]).to be > 1
        expect(error[:message].downcase).to include('end')
      end
    end

    context 'with invalid function syntax' do
      let(:invalid_function_schema) do
        <<~KUMI
          schema do
            input do
              string :name
            end
            value :test, fn()
          end
        KUMI
      end

      it 'detects function syntax error' do
        diagnostics = validator.validate(invalid_function_schema)

        expect(diagnostics.count).to eq(1)
        error = diagnostics.first
        expect(error[:line]).to eq(5)
        expect(error[:message]).not_to be_empty
      end
    end
  end

  describe '#valid?' do
    it 'returns true for valid schema' do
      valid_schema = <<~KUMI
        schema do
          input do
            string :name
          end
          value :greeting, input.name
        end
      KUMI

      expect(validator.valid?(valid_schema)).to be true
    end

    it 'returns false for invalid schema' do
      invalid_schema = <<~KUMI
        schema
          input do
            string :name
          end
        end
      KUMI

      expect(validator.valid?(invalid_schema)).to be false
    end
  end

  describe '#first_error' do
    it 'returns nil for valid schema' do
      valid_schema = <<~KUMI
        schema do
          input do
            string :name
          end
        end
      KUMI

      expect(validator.first_error(valid_schema)).to be_nil
    end

    it 'returns first error message for invalid schema' do
      invalid_schema = <<~KUMI
        schema
          input do
            string :name
          end
        end
      KUMI

      error_message = validator.first_error(invalid_schema)
      expect(error_message).to be_a(String)
      expect(error_message).not_to be_empty
    end
  end
end
