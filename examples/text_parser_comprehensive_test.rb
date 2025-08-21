# frozen_string_literal: true

require_relative '../lib/kumi'

# Comprehensive test of all text parser supported features
# This example tests what the text parser ACTUALLY supports
# (not what the Ruby DSL supports)

module TextParserComprehensiveTest
  extend Kumi::Schema

  schema do
    input do
      # Basic type declarations
      integer :age, domain: 18..65
      float :score, domain: 0.0..100.0
      string :status, domain: %w[active inactive suspended]
      boolean :verified
      any :metadata

      # Nested array declarations
      array :items do
        string :name
        float :price
        integer :quantity
      end
    end

    # ============================================================
    # ARITHMETIC OPERATIONS - All supported operators
    # ============================================================

    # Addition and subtraction
    value :total_price, input.items.price + input.items.quantity
    value :price_diff, input.items.price - 10.0

    # Multiplication and division
    value :scaled_score, input.score * 1.5
    value :average_score, input.score / 2

    # Modulo
    value :remainder, input.age % 10

    # Complex arithmetic with parentheses
    value :complex_calc, (input.score * 2.5) + (input.age / 2) - 10

    # ============================================================
    # COMPARISON OPERATIONS - All comparison operators
    # ============================================================

    trait :adult, input.age >= 18
    trait :senior, input.age > 60
    trait :young_adult, input.age <= 25
    trait :is_teen, input.age < 20
    trait :perfect_score, input.score == 100.0
    trait :not_perfect, input.score != 100.0

    # String comparisons
    trait :is_active, input.status == 'active'
    trait :not_suspended, input.status != 'suspended'

    # Boolean comparisons
    trait :is_verified, input.verified == true
    trait :not_verified, input.verified == false

    # ============================================================
    # LOGICAL OPERATIONS - AND and OR
    # ============================================================

    # AND operations using &
    trait :eligible, (input.age >= 18) & (input.verified == true) & (input.status == 'active')
    trait :premium_user, is_verified & is_active & (input.score > 80.0)

    # OR operations using |
    trait :needs_attention, (input.status == 'suspended') | (input.verified == false)
    trait :special_case, senior | (input.score >= 95.0)

    # Complex logical expressions
    trait :complex_logic, (adult & is_verified) | (senior & is_active)

    # ============================================================
    # FUNCTION CALLS - fn(:name, args) syntax
    # ============================================================

    # Math functions
    value :absolute_diff, fn(:abs, fn(:subtract, input.score, 50.0))
    value :rounded_score, fn(:round, input.score)
    value :clamped_score, fn(:clamp, input.score, 20.0, 80.0)

    # String functions (note: no method syntax like .length)
    value :name_length, fn(:string_length, input.status)
    value :uppercase_status, fn(:upcase, input.status)
    value :lowercase_status, fn(:downcase, input.status)

    # Collection/aggregation functions on arrays
    value :total_items, fn(:sum, input.items.quantity)
    value :item_count, fn(:size, input.items)
    value :max_price, fn(:max, input.items.price)
    value :min_price, fn(:min, input.items.price)

    # ============================================================
    # REFERENCES - Both bare identifiers and ref() NOT supported in text parser
    # ============================================================

    # Using previously defined values/traits (bare identifiers)
    trait :super_eligible, eligible & premium_user
    value :bonus_points, fn(:multiply, total_price, 0.1)

    # ============================================================
    # CASCADE EXPRESSIONS - on/base syntax
    # ============================================================

    value :user_tier do
      on premium_user, 'premium'
      on eligible, 'standard'
      on is_verified, 'basic'
      base 'guest'
    end

    value :discount_rate do
      on senior, 0.25
      on premium_user, 0.15
      on is_active, 0.05
      base 0.0
    end

    # Cascades using complex conditions
    value :risk_level do
      on complex_logic, 'low'
      on needs_attention, 'high'
      on is_active, 'medium'
      base 'unknown'
    end

    # ============================================================
    # NESTED INPUT REFERENCES - Deep field access
    # ============================================================

    # Direct nested field access (parsed as multi-part input reference)
    value :first_item_name, input.items.name
    value :all_prices, input.items.price

    # Operations on nested fields (broadcasting)
    value :discounted_prices, input.items.price * 0.9

    # ============================================================
    # LITERALS - All supported literal types
    # ============================================================

    # Number literals (integers and floats)
    value :constant_int, 42
    value :constant_float, 3.14159

    # String literals (double quotes only)
    value :greeting, 'Hello, World!'

    # Boolean literals
    value :always_true, true
    value :always_false, false

    # ============================================================
    # EDGE CASES AND LIMITATIONS
    # ============================================================

    # Complex parenthesized expressions
    value :nested_parens, ((input.age + 10) * 2) / (input.score - 20)

    # Multiple operators in sequence
    value :operator_chain, input.age + 10 - 5 + 20 - 3

    # Nested function calls
    value :nested_functions, fn(:round, fn(:multiply, fn(:add, input.score, 10), 1.5))

    # ============================================================
    # NOT SUPPORTED (would fail in text parser)
    # ============================================================

    # These are commented out as they would cause parse errors:

    # Array literals in expressions
    # value :array_literal, [1, 2, 3, 4, 5]
    # value :max_of_array, fn(:max, [input.age, 30, 50])

    # Method-style function calls
    # value :method_style, fn.add(input.age, 10)

    # Sugar method calls on fields
    # trait :long_status, input.status.length > 5
    # value :name_chars, input.status.size

    # Ternary/conditional expressions
    # value :conditional, eligible ? 100 : 0

    # Hash literals
    # value :options, { min: 0, max: 100 }

    # ref() syntax
    # trait :ref_example, ref(:eligible) & ref(:premium_user)

    # Symbol literals (except in fn() calls)
    # value :symbol_value, :active

    # Power operator
    # value :squared, input.age ** 2

    # Comments within the DSL
    # value :test, 42 # this would fail
  end
end

# Test the schema with the text parser
if __FILE__ == $0
  require_relative '../lib/kumi/text_parser'

  # Create a clean schema without comments for text parser testing
  schema_text = <<~SCHEMA
    schema do
      input do
        integer :age, domain: 18..65
        float :score, domain: 0.0..100.0
        string :status, domain: %w[active inactive suspended]
        boolean :verified
        any :metadata
    #{'    '}
        array :items do
          string :name
          float :price
          integer :quantity
        end
      end

      value :total_price, input.items.price + input.items.quantity
      value :price_diff, input.items.price - 10.0
      value :scaled_score, input.score * 1.5
      value :average_score, input.score / 2
      value :remainder, input.age % 10
      value :complex_calc, (input.score * 2.5) + (input.age / 2) - 10
    #{'  '}
      trait :adult, input.age >= 18
      trait :senior, input.age > 60
      trait :young_adult, input.age <= 25
      trait :is_teen, input.age < 20
      trait :perfect_score, input.score == 100.0
      trait :not_perfect, input.score != 100.0
      trait :is_active, input.status == "active"
      trait :not_suspended, input.status != "suspended"
      trait :is_verified, input.verified == true
      trait :not_verified, input.verified == false
    #{'  '}
      trait :eligible, (input.age >= 18) & (input.verified == true) & (input.status == "active")
      trait :premium_user, is_verified & is_active & (input.score > 80.0)
      trait :needs_attention, (input.status == "suspended") | (input.verified == false)
      trait :special_case, senior | (input.score >= 95.0)
      trait :complex_logic, (adult & is_verified) | (senior & is_active)
    #{'  '}
      value :absolute_diff, fn(:abs, fn(:subtract, input.score, 50.0))
      value :rounded_score, fn(:round, input.score)
      value :clamped_score, fn(:clamp, input.score, 20.0, 80.0)
      value :name_length, fn(:string_length, input.status)
      value :uppercase_status, fn(:upcase, input.status)
      value :lowercase_status, fn(:downcase, input.status)
      value :total_items, fn(:sum, input.items.quantity)
      value :item_count, fn(:size, input.items)
      value :max_price, fn(:max, input.items.price)
      value :min_price, fn(:min, input.items.price)
    #{'  '}
      trait :super_eligible, eligible & premium_user
      value :bonus_points, fn(:multiply, total_price, 0.1)
    #{'  '}
      value :user_tier do
        on premium_user, "premium"
        on eligible, "standard"
        on is_verified, "basic"
        base "guest"
      end
    #{'  '}
      value :discount_rate do
        on senior, 0.25
        on premium_user, 0.15
        on is_active, 0.05
        base 0.0
      end
    #{'  '}
      value :risk_level do
        on complex_logic, "low"
        on needs_attention, "high"
        on is_active, "medium"
        base "unknown"
      end
    #{'  '}
      value :first_item_name, input.items.name
      value :all_prices, input.items.price
      value :discounted_prices, input.items.price * 0.9
    #{'  '}
      value :constant_int, 42
      value :constant_float, 3.14159
      value :greeting, "Hello, World!"
      value :always_true, true
      value :always_false, false
    #{'  '}
      value :nested_parens, ((input.age + 10) * 2) / (input.score - 20)
      value :operator_chain, input.age + 10 - 5 + 20 - 3
      value :nested_functions, fn(:round, fn(:multiply, fn(:add, input.score, 10), 1.5))
    end
  SCHEMA

  puts 'Testing text parser with comprehensive DSL...'
  puts '=' * 60

  begin
    # Validate the schema
    diagnostics = Kumi::TextParser.validate(schema_text)

    if diagnostics.empty?
      puts '✅ Schema is valid!'

      # Parse and show some info
      ast = Kumi::TextParser.parse(schema_text)
      puts "\nParsed successfully!"
      puts "- Input fields: #{ast.inputs.map(&:name).join(', ')}"
      puts "- Values: #{ast.values.count}"
      puts "- Traits: #{ast.traits.count}"
    else
      puts '❌ Schema has errors:'
      diagnostics.to_a.each do |diagnostic|
        puts "  Line #{diagnostic.line}, Column #{diagnostic.column}: #{diagnostic.message}"
      end
    end
  rescue StandardError => e
    puts "❌ Parser error: #{e.message}"
    puts e.backtrace.first(5)
  end
end
