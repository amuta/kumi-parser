# frozen_string_literal: true

RSpec.describe 'Negative Numbers Support' do
  describe 'tokenization' do
    it 'tokenizes negative integers as single tokens' do
      tokens = tokenize('-42')
      expect(tokens.map(&:type)).to eq(%i[integer eof])
      expect(tokens.first.value).to eq('-42')
    end

    it 'tokenizes negative floats as single tokens' do
      tokens = tokenize('-3.14')
      expect(tokens.map(&:type)).to eq(%i[float eof])
      expect(tokens.first.value).to eq('-3.14')
    end

    it 'distinguishes negative numbers from subtraction operators' do
      # Negative number context (after comma)
      tokens = tokenize('fn(:test, -5)')
      token_types = tokens.map(&:type)
      expect(token_types).to include(:integer)

      negative_token = tokens.find { |t| t.type == :integer }
      expect(negative_token.value).to eq('-5')
    end

    it 'treats minus with space as subtraction operator' do
      tokens = tokenize('x - 5')
      token_types = tokens.map(&:type)
      expect(token_types).to include(:subtract)
      expect(token_types).to include(:integer)

      integer_token = tokens.find { |t| t.type == :integer }
      expect(integer_token.value).to eq('5') # positive
    end
  end

  describe 'parsing' do
    it 'parses negative integer literals' do
      schema = parse_schema('schema do input do end value :test, -42 end')

      value_decl = schema.values.first
      expect(value_decl.expression).to be_a(Kumi::Syntax::Literal)
      expect(value_decl.expression.value).to eq(-42)
    end

    it 'parses negative float literals' do
      schema = parse_schema('schema do input do end value :test, -3.14 end')

      value_decl = schema.values.first
      expect(value_decl.expression).to be_a(Kumi::Syntax::Literal)
      expect(value_decl.expression.value).to eq(-3.14)
    end

    it 'parses negative numbers in function arguments' do
      schema = parse_schema('schema do input do end value :test, fn(:max, -5, -10) end')

      value_decl = schema.values.first
      call_expr = value_decl.expression

      expect(call_expr).to be_a(Kumi::Syntax::CallExpression)
      expect(call_expr.args.first.value).to eq(-5)
      expect(call_expr.args.last.value).to eq(-10)
    end

    it 'parses negative numbers in arithmetic expressions' do
      schema = parse_schema(<<~KUMI)
        schema do
          input do
            integer :balance
          end
          value :adjusted, (input.balance + -100)
        end
      KUMI

      value_decl = schema.values.first
      add_expr = value_decl.expression

      expect(add_expr).to be_a(Kumi::Syntax::CallExpression)
      expect(add_expr.fn_name).to eq(:add)
      expect(add_expr.args.last.value).to eq(-100)
    end

    it 'correctly handles subtraction vs negative in mixed expressions' do
      schema = parse_schema(<<~KUMI)
        schema do
          input do
            integer :x
          end
          value :test, (input.x - -5)
        end
      KUMI

      value_decl = schema.values.first
      subtract_expr = value_decl.expression

      expect(subtract_expr.fn_name).to eq(:subtract)
      expect(subtract_expr.args.first).to be_a(Kumi::Syntax::InputReference)
      expect(subtract_expr.args.last).to be_a(Kumi::Syntax::Literal)
      expect(subtract_expr.args.last.value).to eq(-5)
    end
  end

  describe 'unary minus operator' do
    it 'parses unary minus on input references' do
      schema = parse_schema(<<~KUMI)
        schema do
          input do
            integer :balance
          end
          value :negative_balance, -input.balance
        end
      KUMI

      value_decl = schema.values.first
      subtract_expr = value_decl.expression

      expect(subtract_expr).to be_a(Kumi::Syntax::CallExpression)
      expect(subtract_expr.fn_name).to eq(:subtract)
      expect(subtract_expr.args.first.value).to eq(0)
      expect(subtract_expr.args.last).to be_a(Kumi::Syntax::InputReference)
    end

    it 'parses unary minus on complex expressions' do
      schema = parse_schema(<<~KUMI)
        schema do
          input do
            integer :balance
          end
          value :test, -(input.balance * 2)
        end
      KUMI

      value_decl = schema.values.first
      subtract_expr = value_decl.expression

      expect(subtract_expr.fn_name).to eq(:subtract)
      expect(subtract_expr.args.first.value).to eq(0)
      expect(subtract_expr.args.last).to be_a(Kumi::Syntax::CallExpression)
      expect(subtract_expr.args.last.fn_name).to eq(:multiply)
    end

    it 'respects precedence with parentheses' do
      schema = parse_schema(<<~KUMI)
        schema do
          input do
            integer :balance
          end
          value :test, (-input.balance * 2)
        end
      KUMI

      value_decl = schema.values.first
      multiply_expr = value_decl.expression

      expect(multiply_expr.fn_name).to eq(:multiply)
      expect(multiply_expr.args.first).to be_a(Kumi::Syntax::CallExpression)
      expect(multiply_expr.args.first.fn_name).to eq(:subtract)
    end

    it 'matches Ruby DSL for unary minus' do
      kumi_text = <<~KUMI
        schema do
          input do
            integer :balance
          end
          value :negative_balance, -input.balance
        end
      KUMI

      ruby_schema = Class.new do
        extend Kumi::Schema
        schema do
          input do
            integer :balance
          end
          value :negative_balance, -input.balance
        end
      end

      text_ast = Kumi::Parser::TextParser.parse(kumi_text)
      ruby_ast = ruby_schema.__syntax_tree__

      expect(text_ast).to eq(ruby_ast)
    end
  end

  describe 'Ruby DSL compatibility' do
    it 'produces identical AST for negative integer constants' do
      kumi_text = <<~KUMI
        schema do
          input do
            integer :x
          end
          value :negative_constant, -42
        end
      KUMI

      ruby_schema = Class.new do
        extend Kumi::Schema
        schema do
          input do
            integer :x
          end
          value :negative_constant, -42
        end
      end

      text_ast = Kumi::Parser::TextParser.parse(kumi_text)
      ruby_ast = ruby_schema.__syntax_tree__

      expect(text_ast).to eq(ruby_ast)
    end

    it 'produces identical AST for negative float constants' do
      kumi_text = <<~KUMI
        schema do
          input do
            float :rate
          end
          value :negative_rate, -0.05
        end
      KUMI

      ruby_schema = Class.new do
        extend Kumi::Schema
        schema do
          input do
            float :rate
          end
          value :negative_rate, -0.05
        end
      end

      text_ast = Kumi::Parser::TextParser.parse(kumi_text)
      ruby_ast = ruby_schema.__syntax_tree__

      expect(text_ast).to eq(ruby_ast)
    end

    it 'produces identical AST for negative numbers in expressions' do
      kumi_text = <<~KUMI
        schema do
          input do
            integer :income
          end
          value :adjusted, (input.income + -500)
          value :tax, (input.income * -0.25)
        end
      KUMI

      ruby_schema = Class.new do
        extend Kumi::Schema
        schema do
          input do
            integer :income
          end
          value :adjusted, (input.income + -500)
          value :tax, (input.income * -0.25)
        end
      end

      text_ast = Kumi::Parser::TextParser.parse(kumi_text)
      ruby_ast = ruby_schema.__syntax_tree__

      expect(text_ast).to eq(ruby_ast)
    end

    it 'matches S-expression output for complex negative number usage' do
      kumi_text = <<~KUMI
        schema do
          input do
            integer :balance
            float :rate
          end
          value :debt, -1000
          value :interest, (input.balance * -0.03)
          value :adjustment, (input.balance + -50)
        end
      KUMI

      ruby_schema = Class.new do
        extend Kumi::Schema
        schema do
          input do
            integer :balance
            float :rate
          end
          value :debt, -1000
          value :interest, (input.balance * -0.03)
          value :adjustment, (input.balance + -50)
        end
      end

      text_ast = Kumi::Parser::TextParser.parse(kumi_text)
      ruby_ast = ruby_schema.__syntax_tree__

      text_sexpr = Kumi::Support::SExpressionPrinter.print(text_ast)
      ruby_sexpr = Kumi::Support::SExpressionPrinter.print(ruby_ast)

      expect(text_sexpr).to eq(ruby_sexpr)
    end
  end

  describe 'validation' do
    it 'validates schemas with negative numbers' do
      schema_text = <<~KUMI
        schema do
          input do
            integer :balance
          end
          value :debt, -1000
          value :small_negative, -0.1
          trait :in_debt, (input.balance < -100)
        end
      KUMI

      expect(Kumi::Parser::TextParser.valid?(schema_text)).to be true
    end

    it 'allows negative numbers in trait conditions' do
      schema_text = <<~KUMI
        schema do
          input do
            float :temperature
          end
          trait :freezing, (input.temperature <= -0.1)
          trait :very_cold, (input.temperature < -10)
        end
      KUMI

      expect(Kumi::Parser::TextParser.valid?(schema_text)).to be true

      schema = Kumi::Parser::TextParser.parse(schema_text)
      freezing_trait = schema.traits.first
      condition = freezing_trait.expression

      expect(condition.args.last.value).to eq(-0.1)
    end
  end

  describe 'edge cases' do
    it 'handles multiple consecutive negative numbers' do
      schema_text = <<~KUMI
        schema do
          input do end
          value :a, -1
          value :b, -2
          value :c, -3.14
        end
      KUMI

      schema = Kumi::Parser::TextParser.parse(schema_text)
      values = schema.values.map { |attr| attr.expression.value }

      expect(values).to eq([-1, -2, -3.14])
    end

    it 'handles negative numbers with underscores' do
      schema_text = 'schema do input do end value :big_negative, -1_000_000 end'

      schema = Kumi::Parser::TextParser.parse(schema_text)
      value = schema.values.first.expression.value

      expect(value).to be_a(Integer)
      expect(value.to_s).to eq('-1000000')
    end

    it 'preserves negative zero for floats' do
      schema_text = 'schema do input do end value :neg_zero, -0.0 end'

      schema = Kumi::Parser::TextParser.parse(schema_text)
      value = schema.values.first.expression.value

      expect(value).to eq(-0.0)
      expect(1.0 / value).to be_negative # True negative zero
    end
  end

  private

  def tokenize(text)
    Kumi::Parser::SmartTokenizer.new(text).tokenize
  end

  def parse_schema(text)
    Kumi::Parser::TextParser.parse(text)
  end
end
