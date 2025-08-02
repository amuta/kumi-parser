# frozen_string_literal: true

RSpec.describe Kumi::Parser::SmartTokenizer do
  describe '#tokenize' do
    context 'when encountering tokenizer errors' do
      it 'raises TokenizerError for unterminated string literal' do
        input = 'schema do value :name, "unterminated string'
        tokenizer = described_class.new(input)

        expect { tokenizer.tokenize }.to raise_error(Kumi::Parser::Errors::TokenizerError) do |error|
          expect(error.message).to include('Unterminated string literal')
          expect(error.location).to be_a(Kumi::Syntax::Location)
          expect(error.location.line).to eq(1)
        end
      end

      it 'raises TokenizerError for unexpected = character' do
        input = 'schema do value :test, (x = 5) end'
        tokenizer = described_class.new(input)

        expect { tokenizer.tokenize }.to raise_error(Kumi::Parser::Errors::TokenizerError) do |error|
          expect(error.message).to include("Unexpected '=' (did you mean '=='?)")
          expect(error.location).to be_a(Kumi::Syntax::Location)
        end
      end

      it 'raises TokenizerError for unexpected ! character' do
        input = 'schema do value :test, (!valid) end'
        tokenizer = described_class.new(input)

        expect { tokenizer.tokenize }.to raise_error(Kumi::Parser::Errors::TokenizerError) do |error|
          expect(error.message).to include("Unexpected '!' (did you mean '!='?)")
          expect(error.location).to be_a(Kumi::Syntax::Location)
        end
      end

      it 'raises TokenizerError for unexpected character' do
        input = 'schema do value :test, @ end'
        tokenizer = described_class.new(input)

        expect { tokenizer.tokenize }.to raise_error(Kumi::Parser::Errors::TokenizerError) do |error|
          expect(error.message).to include('Unexpected character: @')
          expect(error.location).to be_a(Kumi::Syntax::Location)
        end
      end
    end

    context 'exponent operator' do
      it 'tokenizes ** as exponent operator' do
        input = '2 ** 3'
        tokenizer = described_class.new(input)
        tokens = tokenizer.tokenize

        expect(tokens.map(&:type)).to eq([:integer, :exponent, :integer, :eof])
        expect(tokens[1].value).to eq('**')
        expect(tokens[1].metadata[:precedence]).to eq(7)
        expect(tokens[1].metadata[:associativity]).to eq(:right)
      end

      it 'distinguishes ** from two separate * tokens' do
        input = '2 * * 3'
        tokenizer = described_class.new(input)
        tokens = tokenizer.tokenize

        expect(tokens.map(&:type)).to eq([:integer, :multiply, :multiply, :integer, :eof])
        expect(tokens[1].value).to eq('*')
        expect(tokens[2].value).to eq('*')
      end
    end
  end
end