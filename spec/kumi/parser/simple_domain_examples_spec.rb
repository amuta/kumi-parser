# frozen_string_literal: true

module SimpleStatusSchema
  extend Kumi::Schema

  schema do
    input do
      string :status, domain: %w[active inactive]
      integer :level, domain: 1..5
    end

    trait :is_active, input.status == 'active'
    trait :high_level, input.level >= 4

    value :display_status, input.status
    value :level_type do
      on high_level, 'advanced'
      base 'basic'
    end
  end
end

RSpec.describe 'Kumi::Parser::TextParser Simple Domain Examples' do
  describe 'basic array and range domains' do
    let(:simple_status_text) do
      <<~KUMI
        schema do
          input do
            string :status, domain: ["active", "inactive"]
            integer :level, domain: 1..5
          end
        #{'  '}
          trait :is_active, input.status == "active"
          trait :high_level, input.level >= 4
        #{'  '}
          value :display_status, input.status
          value :level_type do
            on high_level, "advanced"
            base "basic"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for simple status schema' do
        expect(Kumi::Parser::TextParser.valid?(simple_status_text)).to be true
      end
    end

    context 'when comparing S-expressions' do
      it 'shows Ruby DSL vs Text Parser AST differences' do
        # Get Ruby DSL AST
        ruby_ast = SimpleStatusSchema.__kumi_syntax_tree__

        # Get Text Parser AST
        text_ast = Kumi::Parser::TextParser.parse(simple_status_text)

        # Print both S-expressions for comparison
        # puts "\n=== RUBY DSL S-EXPRESSION ==="
        # puts Kumi::Support::SExpressionPrinter.print(ruby_ast)

        # puts "\n=== TEXT PARSER S-EXPRESSION ==="
        # puts Kumi::Support::SExpressionPrinter.print(text_ast)

        puts "\n=== COMPARISON ==="
        puts "Same number of inputs: #{text_ast.inputs.length == ruby_ast.inputs.length}"
        puts "Same number of traits: #{text_ast.traits.length == ruby_ast.traits.length}"
        puts "Same number of values: #{text_ast.values.length == ruby_ast.values.length}"

        # Compare input structures (ignoring domains)
        text_ast.inputs.each_with_index do |input, idx|
          ruby_input = ruby_ast.inputs[idx]
          puts "Input #{idx}: #{input.name} (#{input.type}) matches #{ruby_input.name} (#{ruby_input.type}): #{input.name == ruby_input.name && input.type == ruby_input.type}"
        end

        # The key difference should be in domain specifications
        ruby_status_input = ruby_ast.inputs.find { |i| i.name == :status }
        text_status_input = text_ast.inputs.find { |i| i.name == :status }

        puts "\nDOMAIN DIFFERENCES:"
        puts "Ruby DSL status domain: #{ruby_status_input.respond_to?(:domain) ? ruby_status_input.domain : 'N/A'}"
        puts "Text Parser status children: #{text_status_input.children}"

        # Core AST structure should be identical except for domains
        expect(text_ast.inputs.length).to eq(ruby_ast.inputs.length)
        expect(text_ast.traits.length).to eq(ruby_ast.traits.length)
        expect(text_ast.values.length).to eq(ruby_ast.values.length)
      end
    end

    it 'executes correctly despite domain specification differences' do
      ast = Kumi::Parser::TextParser.parse(simple_status_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test with values that would be valid in Ruby DSL domains
      valid_data = { status: 'active', level: 5 }
      result = compiled.evaluate(valid_data)

      expect(result.fetch(:display_status)).to eq('active')
      expect(result.fetch(:level_type)).to eq('advanced')

      # Test with values that would be invalid in Ruby DSL domains
      # but work in text parser (no domain enforcement)
      invalid_domain_data = { status: 'unknown', level: 99 }
      invalid_result = compiled.evaluate(invalid_domain_data)

      expect(invalid_result.fetch(:display_status)).to eq('unknown')
      expect(invalid_result.fetch(:level_type)).to eq('advanced') # level >= 4 is still true
    end
  end

  describe 'numeric range domain examples' do
    let(:numeric_ranges_text) do
      <<~KUMI
        schema do
          input do
            integer :count
            float :percentage
          end
        #{'  '}
          trait :high_count, input.count >= 10
          trait :valid_percentage, (input.percentage >= 0.0) & (input.percentage <= 100.0)
        #{'  '}
          value :count_category do
            on high_count, "many"
            base "few"
          end
        #{'  '}
          value :percentage_status do
            on valid_percentage, "valid"
            base "invalid"
          end
        end
      KUMI
    end

    it 'handles numeric comparisons correctly' do
      ast = Kumi::Parser::TextParser.parse(numeric_ranges_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test within ranges
      valid_data = { count: 15, percentage: 75.5 }
      result = compiled.evaluate(valid_data)

      expect(result.fetch(:count_category)).to eq('many')
      expect(result.fetch(:percentage_status)).to eq('valid')

      # Test outside ranges
      invalid_data = { count: 5, percentage: 150.0 }
      invalid_result = compiled.evaluate(invalid_data)

      expect(invalid_result.fetch(:count_category)).to eq('few')
      expect(invalid_result.fetch(:percentage_status)).to eq('invalid')
    end
  end

  describe 'string enumeration domain examples' do
    let(:string_enums_text) do
      <<~KUMI
        schema do
          input do
            string :priority
            string :category
          end
        #{'  '}
          trait :is_urgent, input.priority == "urgent"
          trait :is_bug, input.category == "bug"
          trait :urgent_bug, is_urgent & is_bug
        #{'  '}
          value :escalation_level do
            on urgent_bug, "critical"
            on is_urgent, "high"
            base "normal"
          end
        end
      KUMI
    end

    it 'processes string equality checks like domain validation' do
      ast = Kumi::Parser::TextParser.parse(string_enums_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test urgent bug
      urgent_bug_data = { priority: 'urgent', category: 'bug' }
      result = compiled.evaluate(urgent_bug_data)
      expect(result.fetch(:escalation_level)).to eq('critical')

      # Test urgent non-bug
      urgent_data = { priority: 'urgent', category: 'feature' }
      urgent_result = compiled.evaluate(urgent_data)
      expect(urgent_result.fetch(:escalation_level)).to eq('high')

      # Test normal priority
      normal_data = { priority: 'low', category: 'bug' }
      normal_result = compiled.evaluate(normal_data)
      expect(normal_result.fetch(:escalation_level)).to eq('normal')
    end
  end
end
