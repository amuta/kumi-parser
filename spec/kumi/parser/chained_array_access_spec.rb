# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Chained Array Access' do
  describe 'parsing input.path.to.array[index]' do
    let(:schema_text) do
      <<~KUMI
        schema do
          input do
            hash :grid do
              hash :z do
                hash :y do
                  hash :x do
                    array :ch do
                      element :float, :value
                    end
                  end
                end
              end
            end
          end
          let :u0, input.grid.z.y.x.ch[0]
          let :v0, input.grid.z.y.x.ch[1]
        end
      KUMI
    end

    it 'parses successfully' do
      expect { Kumi::Parser::TextParser.parse(schema_text) }.not_to raise_error
    end

    it 'creates CallExpression(:at) for chained input reference with array access' do
      ast = Kumi::Parser::TextParser.parse(schema_text)

      u0_expr = ast.values[0].expression
      v0_expr = ast.values[1].expression

      expect(u0_expr).to be_a(Kumi::Syntax::CallExpression)
      expect(u0_expr.fn_name).to eq(:at)
      expect(u0_expr.args.length).to eq(2)

      expect(u0_expr.args[0]).to be_a(Kumi::Syntax::InputElementReference)
      expect(u0_expr.args[0].path).to eq([:grid, :z, :y, :x, :ch])

      expect(u0_expr.args[1]).to be_a(Kumi::Syntax::Literal)
      expect(u0_expr.args[1].value).to eq(0)

      expect(v0_expr).to be_a(Kumi::Syntax::CallExpression)
      expect(v0_expr.fn_name).to eq(:at)
      expect(v0_expr.args[1].value).to eq(1)
    end
  end

  describe 'complex array access patterns' do
    it 'handles multiple chained array accesses' do
      schema = <<~KUMI
        schema do
          input do
            array :matrix do
              element :array, :row do
                element :float, :cell
              end
            end
          end
          let :cell, input.matrix[0][1]
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      expr = ast.values[0].expression

      expect(expr).to be_a(Kumi::Syntax::CallExpression)
      expect(expr.fn_name).to eq(:at)
      expect(expr.args[1].value).to eq(1)

      inner = expr.args[0]
      expect(inner).to be_a(Kumi::Syntax::CallExpression)
      expect(inner.fn_name).to eq(:at)
      expect(inner.args[1].value).to eq(0)
    end

    it 'handles array access on binary operations' do
      schema = <<~KUMI
        schema do
          input do
            float :x
          end
          let :result, (input.x + 5)[0]
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      expr = ast.values[0].expression

      expect(expr).to be_a(Kumi::Syntax::CallExpression)
      expect(expr.fn_name).to eq(:at)

      base = expr.args[0]
      expect(base).to be_a(Kumi::Syntax::CallExpression)
      expect(base.fn_name).to eq(:add)
    end

    it 'handles array access on function calls' do
      schema = <<~KUMI
        schema do
          input do
            float :x
          end
          let :result, fn(:split, input.x)[0]
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      expr = ast.values[0].expression

      expect(expr).to be_a(Kumi::Syntax::CallExpression)
      expect(expr.fn_name).to eq(:at)

      base = expr.args[0]
      expect(base).to be_a(Kumi::Syntax::CallExpression)
      expect(base.fn_name).to eq(:split)
    end
  end
end
