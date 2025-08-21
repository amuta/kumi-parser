# frozen_string_literal: true

require_relative '../lib/kumi/text_parser'

# Test schema with comments and verify AST structure
schema_text = <<~SCHEMA
  schema do
    # Input section with type declarations
    input do
      integer :age, domain: 18..65     # User's age
      float :score, domain: 0.0..100.0 # Test score
      string :status, domain: %w[active inactive] # User status
      boolean :verified                # Verification status
  #{'    '}
      # Nested array example
      array :items do
        string :name     # Item name
        float :price     # Item price
        integer :quantity # Item quantity
      end
    end

    # Basic arithmetic operations
    value :total_price, input.items.price + input.items.quantity
    value :scaled_score, input.score * 1.5
  #{'  '}
    # Trait definitions with comparisons
    trait :adult, input.age >= 18    # Is adult
    trait :high_scorer, input.score > 80.0 # High score
    trait :is_active, input.status == "active" # Active user
  #{'  '}
    # Complex logical operations
    trait :eligible, adult & is_active & (input.verified == true)
  #{'  '}
    # Function calls
    value :rounded_score, fn(:round, input.score)
    value :item_count, fn(:size, input.items)
  #{'  '}
    # Cascade expressions
    value :user_level do
      on high_scorer, "premium"  # Premium users
      on eligible, "standard"    # Standard users#{'  '}
      base "basic"              # Default level
    end
  end
SCHEMA

puts 'Testing text parser with comments...'
puts '=' * 50

begin
  # Test parsing
  diagnostics = Kumi::TextParser.validate(schema_text)

  if diagnostics.empty?
    puts '✅ Schema parsed successfully!'

    # Parse and examine AST structure
    ast = Kumi::TextParser.parse(schema_text)

    puts "\n📊 AST Structure:"
    puts "- Root type: #{ast.class.name}"
    puts "- Input fields: #{ast.inputs.count}"
    ast.inputs.each_with_index do |input, i|
      puts "  #{i + 1}. #{input.name} (#{input.type})"
      next unless input.children && input.children.any?

      input.children.each do |child|
        puts "     - #{child.name} (#{child.type})"
      end
    end

    puts "- Value declarations: #{ast.values.count}"
    ast.values.each_with_index do |value, i|
      puts "  #{i + 1}. #{value.name}"
    end

    puts "- Trait declarations: #{ast.traits.count}"
    ast.traits.each_with_index do |trait, i|
      puts "  #{i + 1}. #{trait.name}"
    end

    # Test with actual Ruby DSL to verify it works end-to-end
    puts "\n🧪 Testing with full Kumi analysis..."
    begin
      analyzer = Kumi::Analyzer.new
      analysis_result = analyzer.analyze(ast)

      if analysis_result.errors.any?
        puts '❌ Analysis errors:'
        analysis_result.errors.each do |error|
          if error.respond_to?(:message)
            puts "  - #{error.message}"
          elsif error.is_a?(Array)
            puts "  - #{error[1]}"
          else
            puts "  - #{error}"
          end
        end
      else
        puts '✅ Schema analysis successful!'

        # Try to create a compiled schema
        compiler = Kumi::Compiler.new
        compiled = compiler.compile(ast, analysis_result)
        puts '✅ Schema compilation successful!'

        # Test execution with sample data
        test_data = {
          age: 25,
          score: 85.5,
          status: 'active',
          verified: true,
          items: [
            { name: 'Item 1', price: 10.0, quantity: 2 },
            { name: 'Item 2', price: 15.0, quantity: 1 }
          ]
        }

        runner = Kumi::Runner.new(compiled, test_data)

        # Test a few key calculations
        puts "\n🎯 Test Results:"
        puts "- total_price: #{runner.fetch(:total_price)}"
        puts "- scaled_score: #{runner.fetch(:scaled_score)}"
        puts "- adult: #{runner.fetch(:adult)}"
        puts "- eligible: #{runner.fetch(:eligible)}"
        puts "- user_level: #{runner.fetch(:user_level)}"
        puts "- item_count: #{runner.fetch(:item_count)}"

      end
    rescue StandardError => e
      puts "❌ Analysis/compilation error: #{e.message}"
      puts e.backtrace.first(3)
    end

  else
    puts '❌ Schema has parse errors:'
    diagnostics.to_a.each do |diagnostic|
      puts "  Line #{diagnostic.line}, Column #{diagnostic.column}: #{diagnostic.message}"
    end
  end
rescue StandardError => e
  puts "❌ Unexpected error: #{e.message}"
  puts e.backtrace.first(5)
end
