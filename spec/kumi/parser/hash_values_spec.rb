# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mixed Nested Schema Support' do
  let(:hash_value_schema) { File.read('spec/fixtures/hash_value.rb') }

  describe 'parsing hash value structure' do
    it 'parses successfully' do
      expect { Kumi::Parser::TextParser.parse(hash_value_schema) }.not_to raise_error
    end

    it 'creates correct AST structure' do
      ast = Kumi::Parser::TextParser.parse(hash_value_schema)

      # Verify top-level structure
      expect(ast.inputs.length).to eq(2)
      expect(ast.values.length).to eq(1)

      val_decl = ast.values.first
      expect(val_decl.expression).to be_a(Kumi::Syntax::HashExpression)

      hash_expr = val_decl.expression

      pair1, pair2 = hash_expr.pairs
      expect(pair1.size).to eq(2)
      expect(pair2.size).to eq(2)

      expect(pair1[0]).to be_a(Kumi::Syntax::Literal)
      expect(pair1[0].value).to eq(:key_name)

      expect(pair1[1]).to be_a(Kumi::Syntax::InputReference)
      expect(pair1[1].name).to eq(:name)

      expect(pair2[0]).to be_a(Kumi::Syntax::Literal)
      expect(pair2[0].value).to eq(:key_state)

      expect(pair2[1]).to be_a(Kumi::Syntax::InputReference)
      expect(pair2[1].name).to eq(:state)

      # valudate Hash AST Syntax

      # Verify organization structure (hash with nested children)
    end
    it 'validates successfully' do
      expect(Kumi::Parser::TextParser.valid?(hash_value_schema)).to be true
    end

    describe 'Ruby DSL compatibility' do
      # Define equivalent Ruby DSL AST
      module HashValueSchema
        extend Kumi::Schema

        build_syntax_tree do
          input do
            string :name
            string :state
          end

          value :data, {
            name: input.name,
            state: input.state
          }
        end
      end
    end

    context 'when compared to ruby AST' do
      it 'has identical AST structure' do
        ruby_ast = HashValueSchema.__kumi_syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(hash_value_schema)

        # Direct AST comparison
        expect(text_ast).to eq(ruby_ast)
      end

      it 'produces identical S-expression output' do
        ruby_ast = HashValueSchema.__kumi_syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(hash_value_schema)

        ruby_sexpr = Kumi::Support::SExpressionPrinter.print(ruby_ast)
        text_sexpr = Kumi::Support::SExpressionPrinter.print(text_ast)

        expect(text_sexpr).to eq(ruby_sexpr)
      end
    end
  end
end
