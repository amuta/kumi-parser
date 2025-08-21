# frozen_string_literal: true

module RangeDomainSchema
  extend Kumi::Schema

  schema do
    input do
      integer :age, domain: 18..65
      float :score, domain: 0.0..100.0
      integer :level, domain: 1...11 # exclusive range
    end

    trait :adult, input.age >= 21
    trait :passing, input.score >= 70.0
    trait :max_level, input.level >= 10

    value :age_category do
      on adult, 'adult'
      base 'minor'
    end

    value :grade do
      on passing, 'pass'
      base 'fail'
    end
  end
end

RSpec.describe 'Kumi::Parser::TextParser Range Domains' do
  describe 'range domain specifications' do
    let(:range_domains_text) do
      <<~KUMI
        schema do
          input do
            integer :age, domain: 18..65
            float :score, domain: 0.0..100.0
            integer :level, domain: 1...11
          end
        #{'  '}
          trait :adult, input.age >= 21
          trait :passing, input.score >= 70.0
          trait :max_level, input.level >= 10
        #{'  '}
          value :age_category do
            on adult, "adult"
            base "minor"
          end
        #{'  '}
          value :grade do
            on passing, "pass"
            base "fail"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for range domain schema' do
        expect(Kumi::Parser::TextParser.valid?(range_domains_text)).to be true
      end
    end

    context 'when comparing with Ruby DSL' do
      it 'has identical AST structure including range domains' do
        ruby_ast = RangeDomainSchema.__syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(range_domains_text)

        # puts "\n=== RUBY DSL S-EXPRESSION ==="
        # puts Kumi::Support::SExpressionPrinter.print(ruby_ast)

        # puts "\n=== TEXT PARSER S-EXPRESSION ==="
        # puts Kumi::Support::SExpressionPrinter.print(text_ast)

        # Check if ranges are parsed correctly
        ruby_age_input = ruby_ast.inputs.find { |i| i.name == :age }
        text_age_input = text_ast.inputs.find { |i| i.name == :age }

        puts "\n=== RANGE DOMAIN COMPARISON ==="
        puts "Ruby DSL age domain: #{ruby_age_input.domain}"
        puts "Text Parser age domain: #{text_age_input.domain}"
        puts "Ruby DSL age domain class: #{ruby_age_input.domain.class}"
        puts "Text Parser age domain class: #{text_age_input.domain.class}"
        puts "Ranges equal: #{ruby_age_input.domain == text_age_input.domain}"

        # Check exclusive range
        ruby_level_input = ruby_ast.inputs.find { |i| i.name == :level }
        text_level_input = text_ast.inputs.find { |i| i.name == :level }

        puts "Ruby DSL level domain: #{ruby_level_input.domain}"
        puts "Text Parser level domain: #{text_level_input.domain}"
        puts "Exclusive ranges equal: #{ruby_level_input.domain == text_level_input.domain}"

        expect(text_ast.inputs.length).to eq(ruby_ast.inputs.length)
        expect(text_ast.traits.length).to eq(ruby_ast.traits.length)
        expect(text_ast.values.length).to eq(ruby_ast.values.length)
      end
    end

    it 'executes with range domain validation' do
      ast = Kumi::Parser::TextParser.parse(range_domains_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test with values within range
      valid_data = {
        age: 25,
        score: 85.5,
        level: 5
      }
      result = compiled.evaluate(valid_data)

      expect(result.fetch(:age_category)).to eq('adult')
      expect(result.fetch(:grade)).to eq('pass')

      # Test with different valid values
      young_adult_data = {
        age: 22,
        score: 65.0,
        level: 10
      }
      young_result = compiled.evaluate(young_adult_data)

      expect(young_result.fetch(:age_category)).to eq('adult')
      expect(young_result.fetch(:grade)).to eq('fail')
    end
  end

  describe 'mixed range and array domains' do
    let(:mixed_domains_text) do
      <<~KUMI
        schema do
          input do
            integer :priority, domain: 1..5
            string :status, domain: ["active", "inactive", "pending"]
            float :rating, domain: 0.0...5.0
          end
        #{'  '}
          trait :high_priority, input.priority >= 4
          trait :active_status, input.status == "active"
          trait :excellent_rating, input.rating >= 4.5
        #{'  '}
          value :urgency do
            on high_priority, "important"
            base "normal"
          end
        end
      KUMI
    end

    it 'handles mixed domain types correctly' do
      ast = Kumi::Parser::TextParser.parse(mixed_domains_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test urgent case
      urgent_data = {
        priority: 5,
        status: 'active',
        rating: 4.8
      }
      urgent_result = compiled.evaluate(urgent_data)
      expect(urgent_result.fetch(:urgency)).to eq('important')

      # Test important case
      important_data = {
        priority: 4,
        status: 'pending',
        rating: 3.2
      }
      important_result = compiled.evaluate(important_data)
      expect(important_result.fetch(:urgency)).to eq('important')

      # Test normal case
      normal_data = {
        priority: 2,
        status: 'inactive',
        rating: 2.5
      }
      normal_result = compiled.evaluate(normal_data)
      expect(normal_result.fetch(:urgency)).to eq('normal')
    end
  end

  describe 'range syntax validation' do
    it 'parses inclusive ranges correctly' do
      schema_text = <<~KUMI
        schema do
          input do
            integer :number, domain: 1..10
          end
          trait :valid, input.number >= 1
          value :status, input.number
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema_text)
      number_input = ast.inputs.find { |i| i.name == :number }

      expect(number_input.domain).to eq(1..10)
      expect(number_input.domain.exclude_end?).to be false
    end

    it 'parses exclusive ranges correctly' do
      schema_text = <<~KUMI
        schema do
          input do
            float :percentage, domain: 0.0...100.0
          end
          trait :valid, input.percentage >= 0.0
          value :status, input.percentage
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema_text)
      percentage_input = ast.inputs.find { |i| i.name == :percentage }

      expect(percentage_input.domain).to eq(0.0...100.0)
      expect(percentage_input.domain.exclude_end?).to be true
    end
  end
end
