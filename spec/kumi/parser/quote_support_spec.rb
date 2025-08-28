# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Quote Support' do
  describe 'single and double quote strings' do
    let(:mixed_quotes_text) do
      <<~KUMI
        schema do
          input do
            string :name
          end
          
          value :double_quoted, "hello world"
          value :single_quoted, 'hello world'
          value :mixed_concat, "hello" + 'world'
        end
      KUMI
    end

    let(:hash_in_strings_text) do
      <<~KUMI
        schema do
          input do
            string :name
          end
          
          value :hash_in_double, "This has a # symbol"
          value :hash_in_single, 'This also has a # symbol'
          value :comment_like, "# This looks like a comment but isn't"
        end
      KUMI
    end

    let(:escaped_quotes_text) do
      <<~KUMI
        schema do
          input do
            string :name
          end
          
          value :escaped_double, "She said \\"hello\\""
          value :escaped_single, 'It\\'s working'
          value :mixed_escapes, "Single ' quote inside double"
          value :other_mixed, 'Double " quote inside single'
        end
      KUMI
    end

    it 'parses mixed single and double quotes' do
      expect { Kumi::Parser::TextParser.parse(mixed_quotes_text) }.not_to raise_error
    end

    it 'validates mixed quotes as valid' do
      expect(Kumi::Parser::TextParser.valid?(mixed_quotes_text)).to be true
    end

    it 'handles hash symbols inside strings' do
      expect { Kumi::Parser::TextParser.parse(hash_in_strings_text) }.not_to raise_error
    end

    it 'validates hash symbols in strings as valid' do
      expect(Kumi::Parser::TextParser.valid?(hash_in_strings_text)).to be true
    end

    it 'parses escaped quotes correctly' do
      expect { Kumi::Parser::TextParser.parse(escaped_quotes_text) }.not_to raise_error
    end

    it 'validates escaped quotes as valid' do
      expect(Kumi::Parser::TextParser.valid?(escaped_quotes_text)).to be true
    end

    it 'creates correct AST for mixed quotes' do
      ast = Kumi::Parser::TextParser.parse(mixed_quotes_text)
      
      expect(ast.values.length).to eq(3)
      
      # Check that string values are parsed correctly
      double_quoted = ast.values[0]
      expect(double_quoted.name).to eq(:double_quoted)
      expect(double_quoted.expression).to be_a(Kumi::Syntax::Literal)
      expect(double_quoted.expression.value).to eq("hello world")
      
      single_quoted = ast.values[1]
      expect(single_quoted.name).to eq(:single_quoted)
      expect(single_quoted.expression).to be_a(Kumi::Syntax::Literal)
      expect(single_quoted.expression.value).to eq("hello world")
      
      # Mixed concatenation should be a call expression with add operator
      mixed_concat = ast.values[2]
      expect(mixed_concat.name).to eq(:mixed_concat)
      expect(mixed_concat.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(mixed_concat.expression.fn_name).to eq(:add)
    end
  end

  describe 'Ruby DSL compatibility with quotes' do
    module QuoteSupportSchema
      extend Kumi::Schema

      build_syntax_tree do
        input do
          string :name
        end
        
        value :double_quoted, "hello world"
        value :single_quoted, "hello world"  # Ruby DSL normalizes to double quotes
        value :mixed_concat, "hello" + "world"  # Ruby DSL normalizes to double quotes
        value :complex_concat, "prefix: " + input.name + ' suffix'
      end
    end

    let(:text_with_mixed_quotes) do
      <<~KUMI
        schema do
          input do
            string :name
          end
          
          value :double_quoted, "hello world"
          value :single_quoted, 'hello world'
          value :mixed_concat, "hello" + 'world'
          value :complex_concat, "prefix: " + input.name + ' suffix'
        end
      KUMI
    end

    it 'produces equivalent AST for simple string literals' do
      ruby_ast = QuoteSupportSchema.__syntax_tree__
      text_ast = Kumi::Parser::TextParser.parse(text_with_mixed_quotes)

      # Compare inputs (should be identical)
      expect(text_ast.inputs).to eq(ruby_ast.inputs)
      
      # Compare simple string literal values (first two)
      expect(text_ast.values[0]).to eq(ruby_ast.values[0])  # double_quoted
      expect(text_ast.values[1]).to eq(ruby_ast.values[1])  # single_quoted
      
      # For concatenation: Ruby DSL evaluates to literal, text parser keeps as expression
      # Both are semantically equivalent but structurally different
      ruby_concat = ruby_ast.values[2]
      text_concat = text_ast.values[2]
      
      expect(ruby_concat.name).to eq(text_concat.name)  # Both :mixed_concat
      expect(ruby_concat.expression).to be_a(Kumi::Syntax::Literal)
      expect(text_concat.expression).to be_a(Kumi::Syntax::CallExpression)
    end

    it 'produces similar AST structure for complex concatenation' do
      ruby_ast = QuoteSupportSchema.__syntax_tree__
      text_ast = Kumi::Parser::TextParser.parse(text_with_mixed_quotes)

      # Complex concatenation has same structure but different operators
      ruby_complex = ruby_ast.values[3]
      text_complex = text_ast.values[3]
      
      expect(ruby_complex.name).to eq(text_complex.name)  # Both :complex_concat
      
      # Ruby DSL uses :concat + :add, text parser uses :add + :add
      # But both have the same nested structure with same literals and references
      expect(ruby_complex.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(text_complex.expression).to be_a(Kumi::Syntax::CallExpression)
      
      # Both should have 2 args in the top-level call
      expect(ruby_complex.expression.args.length).to eq(2)
      expect(text_complex.expression.args.length).to eq(2)
      
      # Last arg should be the same literal in both
      expect(ruby_complex.expression.args[1]).to eq(text_complex.expression.args[1])
    end
  end
end