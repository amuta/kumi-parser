# frozen_string_literal: true

RSpec.describe 'Float::INFINITY Support' do
  describe 'tokenization' do
    it 'tokenizes Float::INFINITY as a constant token' do
      tokenizer = Kumi::Parser::SmartTokenizer.new('Float::INFINITY')
      tokens = tokenizer.tokenize

      expect(tokens.length).to eq(2) # constant + eof
      expect(tokens.first.type).to eq(:constant)
      expect(tokens.first.value).to eq('Float::INFINITY')
    end
  end

  describe 'parsing' do
    it 'parses Float::INFINITY as a literal' do
      schema = 'schema do input do float :x end value :max, Float::INFINITY end'
      ast = Kumi::Parser::TextParser.parse(schema)

      expect(ast.values.first.expression.value).to eq(Float::INFINITY)
      expect(ast.values.first.expression.value.infinite?).to eq(1)
    end

    it 'parses Float::INFINITY in arrays' do
      schema = 'schema do input do float :x end value :breaks, [100, 200, Float::INFINITY] end'
      ast = Kumi::Parser::TextParser.parse(schema)

      values = ast.values.first.expression.elements.map(&:value)
      expect(values).to eq([100, 200, Float::INFINITY])
      expect(values.last.infinite?).to eq(1)
    end

    it 'validates schemas with Float::INFINITY' do
      schema = 'schema do input do float :x end value :max, Float::INFINITY end'
      expect(Kumi::Parser::TextParser.valid?(schema)).to be true
    end
  end

  describe 'integration with tax calculation' do
    it 'supports Float::INFINITY in tax bracket arrays like Ruby DSL' do
      text_schema = <<~KUMI
        schema do
          input do
            float :income
          end
          value :brackets, [0, 10_000, 50_000, Float::INFINITY]
          value :rates, [0.10, 0.22, 0.37]
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(text_schema)
      brackets = ast.values.first.expression.elements.map(&:value)

      expect(brackets).to eq([0, 10_000, 50_000, Float::INFINITY])
      expect(brackets.last.infinite?).to eq(1)
    end
  end
end
