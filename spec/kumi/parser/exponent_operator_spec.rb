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
      result_value = ast.values.find { |a| a.name == :result }

      # Should be parsed as CallExpression(:*, [2, CallExpression(:power, [3, 4])])
      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.fn_name).to eq(:multiply)
      expect(result_value.expression.args[0]).to be_a(Kumi::Syntax::Literal)
      expect(result_value.expression.args[0].value).to eq(2)
      expect(result_value.expression.args[1]).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.args[1].fn_name).to eq(:power)
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
      result_value = ast.values.find { |a| a.name == :result }

      # Should be parsed as CallExpression(:power, [2, CallExpression(:power, [3, 4])])
      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.fn_name).to eq(:power)
      expect(result_value.expression.args[0]).to be_a(Kumi::Syntax::Literal)
      expect(result_value.expression.args[0].value).to eq(2)
      expect(result_value.expression.args[1]).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.args[1].fn_name).to eq(:power)
      expect(result_value.expression.args[1].args[0].value).to eq(3)
      expect(result_value.expression.args[1].args[1].value).to eq(4)
    end

    it 'works with parentheses to override precedence' do
      # (2 + 3) ** 4 should parse as CallExpression(:power, [CallExpression(:+, [2, 3]), 4])
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :result, (2 + 3) ** 4
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      result_value = ast.values.find { |a| a.name == :result }

      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.fn_name).to eq(:power)
      expect(result_value.expression.args[0]).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression.args[0].fn_name).to eq(:add)
      expect(result_value.expression.args[1]).to be_a(Kumi::Syntax::Literal)
      expect(result_value.expression.args[1].value).to eq(4)
    end

    it 'tokenizes correctly' do
      input = '2 ** 3'
      tokenizer = Kumi::Parser::SmartTokenizer.new(input)
      tokens = tokenizer.tokenize

      expect(tokens.map(&:type)).to eq(%i[integer exponent integer eof])
      expect(tokens[1].value).to eq('**')
      expect(tokens[1].metadata[:precedence]).to eq(7)
      expect(tokens[1].metadata[:associativity]).to eq(:right)
    end
  end

  describe 'compilation and execution' do
    it 'compiles and executes correctly' do
      schema = <<~KUMI
        schema do
          input do
            integer :base
            integer :exponent
          end
          value :power_result, input.base ** input.exponent
          value :complex_expr, 2 + 3 ** 4
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)

      # Should work with analyzer
      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error
      analysis = Kumi::Analyzer.analyze!(ast)

      # Should work with compiler
      expect { Kumi::Compiler.compile(ast, analyzer: analysis) }.not_to raise_error
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Should execute correctly
      test_data = { base: 2, exponent: 3 }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:power_result)).to eq(8) # 2 ** 3 = 8
      expect(result.fetch(:complex_expr)).to eq(83) # 2 + (3 ** 4) = 2 + 81 = 83
    end

    it 'handles right associativity in execution' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :chained_power, 2 ** 3 ** 2
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      test_data = { x: 1 }
      result = compiled.evaluate(test_data)

      # Should be 2 ** (3 ** 2) = 2 ** 9 = 512, not (2 ** 3) ** 2 = 8 ** 2 = 64
      expect(result.fetch(:chained_power)).to eq(512)
    end

    it 'handles precedence correctly in execution' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :precedence_test, 2 * 3 ** 4
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      test_data = { x: 1 }
      result = compiled.evaluate(test_data)

      # Should be 2 * (3 ** 4) = 2 * 81 = 162, not (2 * 3) ** 4 = 6 ** 4 = 1296
      expect(result.fetch(:precedence_test)).to eq(162)
    end

    it 'allows keywords as field names in input references' do
      # This tests that 'base' (a keyword) can be used as a field name
      schema = <<~KUMI
        schema do
          input do
            integer :base
            integer :input
            integer :value
          end
          value :test_base, input.base
          value :test_input, input.input
          value :test_value, input.value
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      test_data = { base: 10, input: 20, value: 30 }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:test_base)).to eq(10)
      expect(result.fetch(:test_input)).to eq(20)
      expect(result.fetch(:test_value)).to eq(30)
    end
  end
end
