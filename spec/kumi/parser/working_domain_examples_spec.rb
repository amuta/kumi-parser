# frozen_string_literal: true

module WorkingDomainSchema
  extend Kumi::Schema

  schema do
    input do
      string :status, domain: %w[active inactive pending]
      integer :level, domain: [1, 2, 3, 4, 5]
      float :score, domain: [0.0, 25.0, 50.0, 75.0, 100.0]
    end

    trait :is_active, input.status == 'active'
    trait :high_level, input.level >= 4
    trait :passing_score, input.score >= 75.0

    value :status_display, input.status
    value :level_category do
      on high_level, 'advanced'
      base 'basic'
    end

    value :score_grade do
      on passing_score, 'pass'
      base 'fail'
    end
  end
end

RSpec.describe 'Kumi::Parser::TextParser Working Domain Examples' do
  describe 'array domain specifications' do
    let(:array_domains_text) do
      <<~KUMI
        schema do
          input do
            string :status, domain: ["active", "inactive", "pending"]
            integer :level, domain: [1, 2, 3, 4, 5]
            float :score, domain: [0.0, 25.0, 50.0, 75.0, 100.0]
          end
        #{'  '}
          trait :is_active, input.status == "active"
          trait :high_level, input.level >= 4
          trait :passing_score, input.score >= 75.0
        #{'  '}
          value :status_display, input.status
          value :level_category do
            on high_level, "advanced"
            base "basic"
          end
        #{'  '}
          value :score_grade do
            on passing_score, "pass"
            base "fail"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for array domain schema' do
        expect(Kumi::Parser::TextParser.valid?(array_domains_text)).to be true
      end
    end

    context 'when comparing with Ruby DSL' do
      it 'shows domain information in S-expressions' do
        ruby_ast = WorkingDomainSchema.__kumi_syntax_tree__
        text_ast = Kumi::Parser::TextParser.parse(array_domains_text)

        # puts "\n=== RUBY DSL S-EXPRESSION ==="
        # puts Kumi::Support::SExpressionPrinter.print(ruby_ast)

        # puts "\n=== TEXT PARSER S-EXPRESSION ==="
        # puts Kumi::Support::SExpressionPrinter.print(text_ast)

        # Check if text parser now includes domain information
        ruby_status_input = ruby_ast.inputs.find { |i| i.name == :status }
        text_status_input = text_ast.inputs.find { |i| i.name == :status }

        puts "\n=== DOMAIN COMPARISON ==="
        puts "Ruby DSL status domain: #{ruby_status_input.respond_to?(:domain) ? ruby_status_input.domain : 'N/A'}"
        puts "Text Parser status domain: #{text_status_input.respond_to?(:domain) ? text_status_input.domain : 'N/A'}"

        expect(text_ast.inputs.length).to eq(ruby_ast.inputs.length)
        expect(text_ast.traits.length).to eq(ruby_ast.traits.length)
        expect(text_ast.values.length).to eq(ruby_ast.values.length)
      end
    end

    it 'executes with domain-aware validation' do
      ast = Kumi::Parser::TextParser.parse(array_domains_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test with valid domain values
      valid_data = {
        status: 'active',
        level: 5,
        score: 85.0
      }
      result = compiled.evaluate(valid_data)

      expect(result.fetch(:status_display)).to eq('active')
      expect(result.fetch(:level_category)).to eq('advanced')
      expect(result.fetch(:score_grade)).to eq('pass')

      # Test with different valid domain values
      other_valid_data = {
        status: 'pending',
        level: 2,
        score: 50.0
      }
      other_result = compiled.evaluate(other_valid_data)

      expect(other_result.fetch(:status_display)).to eq('pending')
      expect(other_result.fetch(:level_category)).to eq('basic')
      expect(other_result.fetch(:score_grade)).to eq('fail')
    end
  end

  describe 'mixed type domains with logical operators' do
    let(:mixed_domains_text) do
      <<~KUMI
        schema do
          input do
            string :priority, domain: ["low", "medium", "high", "urgent"]
            integer :count
            float :percentage
          end
        #{'  '}
          trait :is_urgent, input.priority == "urgent"
          trait :high_count, input.count >= 10
          trait :valid_percentage, (input.percentage >= 0.0) & (input.percentage <= 100.0)
          trait :urgent_and_high, is_urgent & high_count
        #{'  '}
          value :escalation_level do
            on urgent_and_high, "critical"
            on is_urgent, "high"
            base "normal"
          end
        #{'  '}
          value :validation_status do
            on valid_percentage, "valid"
            base "invalid"
          end
        end
      KUMI
    end

    it 'handles complex logical combinations' do
      ast = Kumi::Parser::TextParser.parse(mixed_domains_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test urgent + high count
      critical_data = {
        priority: 'urgent',
        count: 15,
        percentage: 85.5
      }
      critical_result = compiled.evaluate(critical_data)

      expect(critical_result.fetch(:escalation_level)).to eq('critical')
      expect(critical_result.fetch(:validation_status)).to eq('valid')

      # Test urgent + low count
      high_data = {
        priority: 'urgent',
        count: 5,
        percentage: 150.0
      }
      high_result = compiled.evaluate(high_data)

      expect(high_result.fetch(:escalation_level)).to eq('high')
      expect(high_result.fetch(:validation_status)).to eq('invalid')

      # Test normal priority
      normal_data = {
        priority: 'medium',
        count: 20,
        percentage: 75.0
      }
      normal_result = compiled.evaluate(normal_data)

      expect(normal_result.fetch(:escalation_level)).to eq('normal')
      expect(normal_result.fetch(:validation_status)).to eq('valid')
    end
  end
end
