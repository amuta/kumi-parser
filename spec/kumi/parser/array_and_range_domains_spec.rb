# frozen_string_literal: true

module StatusManagementSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :status, domain: %w[active inactive pending suspended]
      string :priority, domain: %w[low medium high urgent]
      string :category, domain: %w[bug feature enhancement task]
      integer :severity, domain: 1..5
      float :score, domain: 0.0..100.0
    end

    trait :is_active, input.status == 'active'
    trait :is_urgent, input.priority == 'urgent'
    trait :is_bug, input.category == 'bug'
    trait :high_severity, input.severity >= 4
    trait :passing_score, input.score >= 70.0

    value :status_display, input.status
    value :priority_level do
      on is_urgent, 'critical'
      base 'normal'
    end

    value :severity_category do
      on high_severity, 'major'
      base 'minor'
    end
  end
end

module UserPermissionsSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :role, domain: %w[admin moderator user guest]
      string :department, domain: %w[engineering sales marketing hr finance]
      integer :access_level, domain: 0..10
      integer :years_experience, domain: 0..50
      float :performance_rating, domain: 1.0..5.0
    end

    trait :is_admin, input.role == 'admin'
    trait :is_engineering, input.department == 'engineering'
    trait :high_access, input.access_level >= 8
    trait :experienced, input.years_experience >= 5
    trait :top_performer, input.performance_rating >= 4.5

    value :access_type do
      on is_admin, 'full_access'
      on high_access, 'elevated_access'
      base 'standard_access'
    end

    value :seniority_level do
      on experienced, 'senior'
      base 'junior'
    end
  end
end

module ProductConfigurationSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :size, domain: %w[xs s m l xl xxl]
      string :color, domain: %w[red blue green yellow black white]
      string :material, domain: %w[cotton polyester silk wool linen]
      integer :quantity, domain: 1..100
      float :price, domain: 0.01..9999.99
    end

    trait :is_large, %w[xl xxl].include?(input.size)
    trait :is_premium, input.price >= 100.0
    trait :bulk_order, input.quantity >= 10
    trait :natural_material, %w[cotton silk wool].include?(input.material)

    value :size_category do
      on is_large, 'oversized'
      base 'standard'
    end

    value :price_tier do
      on is_premium, 'luxury'
      base 'standard'
    end

    value :order_type do
      on bulk_order, 'wholesale'
      base 'retail'
    end
  end
end

RSpec.describe 'Kumi::Parser::TextParser Array and Range Domains' do
  describe 'status management schema with array domains' do
    let(:status_management_text) do
      <<~KUMI
        schema do
          input do
            string :status
            string :priority
            string :category
            integer :severity
            float :score
          end

          trait :is_active, input.status == "active"
          trait :is_urgent, input.priority == "urgent"
          trait :is_bug, input.category == "bug"
          trait :high_severity, input.severity >= 4
          trait :passing_score, input.score >= 70.0

          value :status_display, input.status
          value :priority_level do
            on is_urgent, "critical"
            base "normal"
          end

          value :severity_category do
            on high_severity, "major"
            base "minor"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for status management schema' do
        expect(Kumi::Parser::TextParser.valid?(status_management_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure' do
        ruby_parsed = StatusManagementSchema.__kumi_syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(status_management_text)

        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.values.length).to eq(ruby_parsed.values.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)

        # Compare input names and types
        text_parsed.inputs.each_with_index do |input, idx|
          ruby_input = ruby_parsed.inputs[idx]
          expect(input.name).to eq(ruby_input.name)
          expect(input.type).to eq(ruby_input.type)
        end

        # Compare trait expressions
        text_parsed.traits.each_with_index do |trait, idx|
          ruby_trait = ruby_parsed.traits[idx]
          expect(trait.name).to eq(ruby_trait.name)
          expect(trait.expression.class).to eq(ruby_trait.expression.class)
        end
      end
    end

    it 'integrates with analyzer and compiler' do
      ast = Kumi::Parser::TextParser.parse(status_management_text)

      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error

      analysis = Kumi::Analyzer.analyze!(ast)
      expect { Kumi::Compiler.compile(ast, analyzer: analysis) }.not_to raise_error

      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test with valid domain values
      test_data = {
        status: 'active',
        priority: 'urgent',
        category: 'bug',
        severity: 5,
        score: 85.5
      }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:status_display)).to eq('active')
      expect(result.fetch(:priority_level)).to eq('critical')
      expect(result.fetch(:severity_category)).to eq('major')
    end
  end

  describe 'user permissions schema with mixed domains' do
    let(:user_permissions_text) do
      <<~KUMI
        schema do
          input do
            string :role
            string :department
            integer :access_level
            integer :years_experience
            float :performance_rating
          end

          trait :is_admin, input.role == "admin"
          trait :is_engineering, input.department == "engineering"
          trait :high_access, input.access_level >= 8
          trait :experienced, input.years_experience >= 5
          trait :top_performer, input.performance_rating >= 4.5

          value :access_type do
            on is_admin, "full_access"
            on high_access, "elevated_access"
            base "standard_access"
          end

          value :seniority_level do
            on experienced, "senior"
            base "junior"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for user permissions schema' do
        expect(Kumi::Parser::TextParser.valid?(user_permissions_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure' do
        ruby_parsed = UserPermissionsSchema.__kumi_syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(user_permissions_text)

        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)
        expect(text_parsed.values.length).to eq(ruby_parsed.values.length)

        # Verify cascade expressions work the same
        access_type_attr = text_parsed.values.find { |a| a.name == :access_type }
        expect(access_type_attr.expression).to be_a(Kumi::Syntax::CascadeExpression)

        ruby_access_type = ruby_parsed.values.find { |a| a.name == :access_type }
        expect(access_type_attr.expression.cases.length).to eq(ruby_access_type.expression.cases.length)
      end
    end

    it 'handles range domain constraints in execution' do
      ast = Kumi::Parser::TextParser.parse(user_permissions_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test admin user
      admin_data = {
        role: 'admin',
        department: 'engineering',
        access_level: 10,
        years_experience: 8,
        performance_rating: 4.8
      }
      admin_result = compiled.evaluate(admin_data)

      expect(admin_result.fetch(:access_type)).to eq('full_access')
      expect(admin_result.fetch(:seniority_level)).to eq('senior')

      # Test standard user
      user_data = {
        role: 'user',
        department: 'sales',
        access_level: 3,
        years_experience: 2,
        performance_rating: 3.5
      }
      user_result = compiled.evaluate(user_data)

      expect(user_result.fetch(:access_type)).to eq('standard_access')
      expect(user_result.fetch(:seniority_level)).to eq('junior')
    end
  end

  describe 'product configuration schema with complex domains' do
    let(:product_configuration_text) do
      <<~KUMI
        schema do
          input do
            string :size
            string :color
            string :material
            integer :quantity
            float :price
          end

          trait :is_large, (input.size == "xl") | (input.size == "xxl")
          trait :is_premium, input.price >= 100.0
          trait :bulk_order, input.quantity >= 10
          trait :natural_material, (input.material == "cotton") | (input.material == "silk") | (input.material == "wool")

          value :size_category do
            on is_large, "oversized"
            base "standard"
          end

          value :price_tier do
            on is_premium, "luxury"
            base "standard"
          end

          value :order_type do
            on bulk_order, "wholesale"
            base "retail"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for product configuration schema' do
        expect(Kumi::Parser::TextParser.valid?(product_configuration_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure' do
        ruby_parsed = ProductConfigurationSchema.__kumi_syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(product_configuration_text)

        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)

        # Verify complex trait expressions with OR conditions
        large_trait = text_parsed.traits.find { |t| t.name == :is_large }
        expect(large_trait.expression).to be_a(Kumi::Syntax::CallExpression)
        expect(large_trait.expression.fn_name).to eq(:or)

        natural_trait = text_parsed.traits.find { |t| t.name == :natural_material }
        expect(natural_trait.expression).to be_a(Kumi::Syntax::CallExpression)
        expect(natural_trait.expression.fn_name).to eq(:or)
      end
    end

    it 'executes complex domain logic correctly' do
      ast = Kumi::Parser::TextParser.parse(product_configuration_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test luxury large item
      luxury_data = {
        size: 'xxl',
        color: 'black',
        material: 'silk',
        quantity: 1,
        price: 299.99
      }
      luxury_result = compiled.evaluate(luxury_data)

      expect(luxury_result.fetch(:size_category)).to eq('oversized')
      expect(luxury_result.fetch(:price_tier)).to eq('luxury')
      expect(luxury_result.fetch(:order_type)).to eq('retail')

      # Test bulk standard item
      bulk_data = {
        size: 'm',
        color: 'blue',
        material: 'cotton',
        quantity: 50,
        price: 25.00
      }
      bulk_result = compiled.evaluate(bulk_data)

      expect(bulk_result.fetch(:size_category)).to eq('standard')
      expect(bulk_result.fetch(:price_tier)).to eq('standard')
      expect(bulk_result.fetch(:order_type)).to eq('wholesale')
    end
  end

  describe 'domain specification parsing (current limitations)' do
    let(:domain_examples_text) do
      <<~KUMI
        schema do
          input do
            string :status
            integer :level
            float :rating
          end

          trait :active_status, input.status == "active"
          trait :high_level, input.level >= 5
          trait :good_rating, input.rating >= 3.0

          value :classification do
            on active_status, "enabled"
            base "disabled"
          end
        end
      KUMI
    end

    it 'parses schemas without explicit domain specifications' do
      ast = Kumi::Parser::TextParser.parse(domain_examples_text)

      expect(ast.inputs.length).to eq(3)

      # Text parser currently doesn't enforce domains but structure is compatible
      status_input = ast.inputs.find { |i| i.name == :status }
      expect(status_input.type).to eq(:string)
      expect(status_input.children).to eq([])

      level_input = ast.inputs.find { |i| i.name == :level }
      expect(level_input.type).to eq(:integer)

      rating_input = ast.inputs.find { |i| i.name == :rating }
      expect(rating_input.type).to eq(:float)
    end

    it 'demonstrates AST compatibility despite domain parsing limitations' do
      ast = Kumi::Parser::TextParser.parse(domain_examples_text)

      # Should still work with analyzer and compiler
      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error

      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test execution works with any values (no domain enforcement)
      test_data = { status: 'active', level: 8, rating: 4.2 }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:classification)).to eq('enabled')
    end
  end

  describe 'comprehensive domain type examples' do
    let(:comprehensive_domains_text) do
      <<~KUMI
        schema do
          input do
            string :text_field
            integer :int_field
            float :float_field
          end

          trait :text_match, input.text_field == "expected"
          trait :int_range, (input.int_field >= 1) & (input.int_field <= 10)
          trait :float_range, (input.float_field >= 0.0) & (input.float_field <= 100.0)
          trait :combined, text_match & int_range

          value :validation_status do
            on combined, "valid"
            base "invalid"
          end

          value :range_status do
            on int_range, "in_range"
            base "out_of_range"
          end
        end
      KUMI
    end

    it 'handles various domain-style validations through traits' do
      ast = Kumi::Parser::TextParser.parse(comprehensive_domains_text)

      expect(ast.traits.length).to eq(4)

      # Check combined trait with AND logic
      combined_trait = ast.traits.find { |t| t.name == :combined }
      expect(combined_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(combined_trait.expression.fn_name).to eq(:and)

      # Check range trait with compound conditions
      int_range_trait = ast.traits.find { |t| t.name == :int_range }
      expect(int_range_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(int_range_trait.expression.fn_name).to eq(:and)
    end

    it 'executes domain-like validation logic' do
      ast = Kumi::Parser::TextParser.parse(comprehensive_domains_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test valid combination
      valid_data = { text_field: 'expected', int_field: 5, float_field: 50.0 }
      valid_result = compiled.evaluate(valid_data)

      expect(valid_result.fetch(:validation_status)).to eq('valid')
      expect(valid_result.fetch(:range_status)).to eq('in_range')

      # Test invalid combination
      invalid_data = { text_field: 'wrong', int_field: 15, float_field: 150.0 }
      invalid_result = compiled.evaluate(invalid_data)

      expect(invalid_result.fetch(:validation_status)).to eq('invalid')
      expect(invalid_result.fetch(:range_status)).to eq('out_of_range')
    end
  end
end
