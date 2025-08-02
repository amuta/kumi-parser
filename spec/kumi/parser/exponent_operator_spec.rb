# frozen_string_literal: true

RSpec.describe 'Exponent Operator (**)' do
  describe 'precedence and associativity' do
    it 'has higher precedence than multiplication' do
      # 2 * 3 ** 4 should parse as 2 * (3 ** 4) = 2 * 81 = 162
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :result, 2 * 3 ** 4
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      result_value = ast.attributes.find { |a| a.name == :result }

      # Should be parsed as CallExpression(:*, [2, CallExpression(:**, [3, 4])])
      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.fn_name).to eq(:multiply)
      expect(result_value.expression.args[0]).to be_a(Kumi::Syntax::Literal)
      expect(result_value.expression.args[0].value).to eq(2)
      expect(result_value.expression.args[1]).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.args[1].fn_name).to eq(:**)
      expect(result_value.expression.args[1].args[0].value).to eq(3)
      expect(result_value.expression.args[1].args[1].value).to eq(4)
    end

    it 'is right associative' do
      # 2 ** 3 ** 4 should parse as 2 ** (3 ** 4) = 2 ** 81
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :result, 2 ** 3 ** 4
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      result_value = ast.attributes.find { |a| a.name == :result }

      # Should be parsed as CallExpression(:**, [2, CallExpression(:**, [3, 4])])
      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.fn_name).to eq(:**)
      expect(result_value.expression.args[0]).to be_a(Kumi::Syntax::Literal)
      expect(result_value.expression.args[0].value).to eq(2)
      expect(result_value.expression.args[1]).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.args[1].fn_name).to eq(:**)
      expect(result_value.expression.args[1].args[0].value).to eq(3)
      expect(result_value.expression.args[1].args[1].value).to eq(4)
    end

    it 'works with parentheses to override precedence' do
      # (2 + 3) ** 4 should parse as CallExpression(:**, [CallExpression(:+, [2, 3]), 4])
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :result, (2 + 3) ** 4
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      result_value = ast.attributes.find { |a| a.name == :result }

      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.fn_name).to eq(:**)
      expect(result_value.expression.args[0]).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.args[0].fn_name).to eq(:add)
      expect(result_value.expression.args[1]).to be_a(Kumi::Syntax::Literal)
      expect(result_value.expression.args[1].value).to eq(4)
    end

    it 'tokenizes correctly' do
      input = '2 ** 3'
      tokenizer = Kumi::Parser::SmartTokenizer.new(input)
      tokens = tokenizer.tokenize

      expect(tokens.map(&:type)).to eq([:integer, :exponent, :integer, :eof])
      expect(tokens[1].value).to eq('**')
      expect(tokens[1].metadata[:precedence]).to eq(7)
      expect(tokens[1].metadata[:associativity]).to eq(:right)
    end
  end
end