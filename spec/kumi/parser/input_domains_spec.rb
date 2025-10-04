# frozen_string_literal: true

module UserRegistrationSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :username, domain: %w[admin user guest moderator]
      string :email
      string :status, domain: %w[active inactive suspended]
      integer :age, domain: 18..65
      float :score, domain: 0.0..100.0
    end

    trait :is_admin, input.username == 'admin'
    trait :is_adult, input.age >= 21
    trait :high_score, input.score >= 80.0

    value :display_name, input.username
    value :is_valid_email, input.email

    value :user_level do
      on is_admin, 'administrator'
      on high_score, 'premium'
      base 'standard'
    end
  end
end

module ProductCatalogSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :category, domain: %w[electronics clothing books toys]
      string :brand, domain: %w[apple samsung nike adidas]
      string :condition, domain: %w[new used refurbished]
      float :price, domain: 0.0..10_000.0
      integer :stock, domain: 0..1000
    end

    trait :electronics, input.category == 'electronics'
    trait :expensive, input.price >= 500.0
    trait :in_stock, input.stock > 0

    value :category_display, input.category
    value :price_tier do
      on expensive, 'premium'
      base 'standard'
    end

    value :availability do
      on in_stock, 'available'
      base 'out_of_stock'
    end
  end
end

RSpec.describe 'Kumi::Parser::TextParser Input Domains' do
  describe 'user registration schema with domains' do
    let(:user_registration_text) do
      <<~KUMI
        schema do
          input do
            string :username
            string :email
            string :status
            integer :age
            float :score
          end

          trait :is_admin, input.username == "admin"
          trait :is_adult, input.age >= 21
          trait :high_score, input.score >= 80.0

          value :display_name, input.username
          value :is_valid_email, input.email
        #{'  '}
          value :user_level do
            on is_admin, "administrator"
            on high_score, "premium"
            base "standard"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for user registration schema' do
        expect(Kumi::Parser::TextParser.valid?(user_registration_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure (excluding domain specifications)' do
        ruby_parsed = UserRegistrationSchema.__kumi_syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(user_registration_text)

        # Compare basic structure
        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.values.length).to eq(ruby_parsed.values.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)

        # Compare input names and types
        text_parsed.inputs.each_with_index do |input, idx|
          ruby_input = ruby_parsed.inputs[idx]
          expect(input.name).to eq(ruby_input.name)
          expect(input.type).to eq(ruby_input.type)
          # NOTE: Domain specifications differ between Ruby DSL and text parser
        end

        # Compare trait names and expressions
        text_parsed.traits.each_with_index do |trait, idx|
          ruby_trait = ruby_parsed.traits[idx]
          expect(trait.name).to eq(ruby_trait.name)
          expect(trait.expression.class).to eq(ruby_trait.expression.class)
        end

        # Compare value names
        text_parsed.values.each_with_index do |attr, idx|
          ruby_attr = ruby_parsed.values[idx]
          expect(attr.name).to eq(ruby_attr.name)
        end
      end
    end

    it 'parses input declarations correctly' do
      ast = Kumi::Parser::TextParser.parse(user_registration_text)

      expect(ast.inputs.length).to eq(5)

      username_input = ast.inputs.find { |i| i.name == :username }
      expect(username_input.type).to eq(:string)

      age_input = ast.inputs.find { |i| i.name == :age }
      expect(age_input.type).to eq(:integer)

      score_input = ast.inputs.find { |i| i.name == :score }
      expect(score_input.type).to eq(:float)
    end

    it 'parses traits with domain-related conditions' do
      ast = Kumi::Parser::TextParser.parse(user_registration_text)

      expect(ast.traits.length).to eq(3)

      admin_trait = ast.traits.find { |t| t.name == :is_admin }
      expect(admin_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(admin_trait.expression.fn_name).to eq(:==)

      adult_trait = ast.traits.find { |t| t.name == :is_adult }
      expect(adult_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(adult_trait.expression.fn_name).to eq(:>=)
    end
  end

  describe 'product catalog schema with domains' do
    let(:product_catalog_text) do
      <<~KUMI
        schema do
          input do
            string :category
            string :brand
            string :condition
            float :price
            integer :stock
          end

          trait :electronics, input.category == "electronics"
          trait :expensive, input.price >= 500.0
          trait :in_stock, input.stock > 0

          value :category_display, input.category
          value :price_tier do
            on expensive, "premium"
            base "standard"
          end

          value :availability do
            on in_stock, "available"
            base "out_of_stock"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for product catalog schema' do
        expect(Kumi::Parser::TextParser.valid?(product_catalog_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure (excluding domain specifications)' do
        ruby_parsed = ProductCatalogSchema.__kumi_syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(product_catalog_text)

        # Compare basic structure
        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.values.length).to eq(ruby_parsed.values.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)

        # Compare input specifications
        text_parsed.inputs.each_with_index do |input, idx|
          ruby_input = ruby_parsed.inputs[idx]
          expect(input.name).to eq(ruby_input.name)
          expect(input.type).to eq(ruby_input.type)
        end
      end
    end

    it 'integrates with analyzer and compiler' do
      ast = Kumi::Parser::TextParser.parse(product_catalog_text)

      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error

      analysis = Kumi::Analyzer.analyze!(ast)
      expect { Kumi::Compiler.compile(ast, analyzer: analysis) }.not_to raise_error

      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test execution with domain-compatible values
      test_data = {
        category: 'electronics',
        brand: 'apple',
        condition: 'new',
        price: 999.99,
        stock: 5
      }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:category_display)).to eq('electronics')
      expect(result.fetch(:price_tier)).to eq('premium')
      expect(result.fetch(:availability)).to eq('available')
    end
  end

  describe 'text matching domain examples' do
    let(:text_matching_schema) do
      <<~KUMI
        schema do
          input do
            string :email
            string :phone
            string :postal_code
            string :username
          end

          trait :valid_email, input.email == "user@example.com"
          trait :has_phone, input.phone == "1234567890"
          trait :valid_postal, input.postal_code == "12345"

          value :contact_method do
            on valid_email, "email"
            on has_phone, "phone"
            base "mail"
          end

          value :user_display, input.username
        end
      KUMI
    end

    it 'parses text matching patterns correctly' do
      ast = Kumi::Parser::TextParser.parse(text_matching_schema)

      expect(ast).to be_a(Kumi::Syntax::Root)
      expect(ast.inputs.length).to eq(4)
      expect(ast.traits.length).to eq(3)

      # Check email validation trait
      email_trait = ast.traits.find { |t| t.name == :valid_email }
      expect(email_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(email_trait.expression.fn_name).to eq(:==)
    end

    it 'executes text matching validations end-to-end' do
      ast = Kumi::Parser::TextParser.parse(text_matching_schema)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test with valid email
      valid_data = {
        email: 'user@example.com',
        phone: '1234567890',
        postal_code: '12345',
        username: 'testuser'
      }
      result = compiled.evaluate(valid_data)

      expect(result.fetch(:contact_method)).to eq('email')
      expect(result.fetch(:user_display)).to eq('testuser')
    end
  end

  describe 'domain limitation examples' do
    let(:domain_limitation_text) do
      <<~KUMI
        schema do
          input do
            string :status
            integer :priority
            float :rating
          end

          trait :active, input.status == "active"
          trait :high_priority, input.priority >= 5
          trait :good_rating, input.rating >= 4.0

          value :status_display, input.status
          value :priority_level do
            on high_priority, "urgent"
            base "normal"
          end
        end
      KUMI
    end

    it 'demonstrates current domain parsing limitations' do
      ast = Kumi::Parser::TextParser.parse(domain_limitation_text)

      # Text parser currently doesn't enforce domain constraints
      # but the AST structure is still compatible
      expect(ast.inputs.length).to eq(3)

      status_input = ast.inputs.find { |i| i.name == :status }
      expect(status_input.type).to eq(:string)
      # Domain specification would be nil in text parser
      expect(status_input.children).to be_empty
    end

    it 'shows AST compatibility despite domain differences' do
      # This test demonstrates that while domain specifications differ,
      # the core AST structure remains compatible between Ruby DSL and text parser
      ast = Kumi::Parser::TextParser.parse(domain_limitation_text)

      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error

      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Execution works regardless of domain specification differences
      test_data = { status: 'active', priority: 7, rating: 4.5 }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:status_display)).to eq('active')
      expect(result.fetch(:priority_level)).to eq('urgent')
    end
  end
end
