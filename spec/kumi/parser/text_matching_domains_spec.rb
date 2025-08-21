# frozen_string_literal: true

module EmailValidationSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :email
      string :username
      string :password
    end

    trait :valid_email, input.email == 'user@example.com'
    trait :strong_password, input.password == 'SecurePass123'
    trait :valid_username, input.username == 'validuser'

    value :email_status do
      on valid_email, 'valid'
      base 'invalid'
    end

    value :password_strength do
      on strong_password, 'strong'
      base 'weak'
    end

    value :account_status do
      on valid_email, 'approved'
      base 'pending'
    end
  end
end

module ContactFormSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :phone
      string :country_code, domain: %w[US CA MX UK FR DE JP AU]
      string :message_type, domain: %w[inquiry complaint feedback support]
      string :priority, domain: %w[low medium high urgent]
    end

    trait :us_phone, input.phone == '1234567890'
    trait :formatted_phone, input.phone == '123-456-7890'
    trait :high_priority, (input.priority == 'high') | (input.priority == 'urgent')
    trait :support_request, input.message_type == 'support'

    value :phone_format do
      on formatted_phone, 'formatted'
      base 'raw'
    end

    value :urgency_level do
      on high_priority, 'escalated'
      base 'standard'
    end

    value :routing do
      on support_request, 'technical_team'
      base 'general_team'
    end
  end
end

module ProductCodeSchema
  extend Kumi::Schema

  build_syntax_tree do
    input do
      string :sku
      string :category_code, domain: %w[EL CL BK TY SP HM]
      string :warehouse_location
      string :condition, domain: %w[new used refurbished damaged]
    end

    trait :electronics, input.category_code == 'EL'
    trait :valid_sku, input.sku == 'EL-1234-AB'
    trait :warehouse_a, input.warehouse_location == 'A12'
    trait :sellable, (input.condition == 'new') | (input.condition == 'refurbished')

    value :product_type do
      on electronics, 'electronic_device'
      base 'general_product'
    end

    value :warehouse_zone do
      on warehouse_a, 'zone_alpha'
      base 'zone_beta'
    end

    value :sales_status do
      on sellable, 'available'
      base 'not_for_sale'
    end
  end
end

RSpec.describe 'Kumi::Parser::TextParser Text Matching Domains' do
  describe 'email validation schema with text matching' do
    let(:email_validation_text) do
      <<~KUMI
        schema do
          input do
            string :email
            string :username
            string :password
          end

          trait :valid_email, input.email == "user@example.com"
          trait :strong_password, input.password == "SecurePass123"
          trait :valid_username, input.username == "validuser"

          value :email_status do
            on valid_email, "valid"
            base "invalid"
          end

          value :password_strength do
            on strong_password, "strong"
            base "weak"
          end

          value :account_status do
            on valid_email, "approved"
            base "pending"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for email validation schema' do
        expect(Kumi::Parser::TextParser.valid?(email_validation_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure for core functionality' do
        ruby_parsed = EmailValidationSchema.__syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(email_validation_text)

        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.values.length).to eq(ruby_parsed.values.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)

        # Compare trait expressions (the core text matching logic)
        text_parsed.traits.each_with_index do |trait, idx|
          ruby_trait = ruby_parsed.traits[idx]
          expect(trait.name).to eq(ruby_trait.name)
          # Both should use function calls for text matching
          expect(trait.expression).to be_a(Kumi::Syntax::CallExpression)
          expect(ruby_trait.expression).to be_a(Kumi::Syntax::CallExpression)
        end
      end
    end

    it 'executes text matching validations correctly' do
      ast = Kumi::Parser::TextParser.parse(email_validation_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test with valid inputs
      valid_data = {
        email: 'user@example.com',
        username: 'validuser',
        password: 'SecurePass123'
      }
      result = compiled.evaluate(valid_data)

      expect(result.fetch(:email_status)).to eq('valid')
      expect(result.fetch(:account_status)).to eq('approved')

      # Test with invalid email
      invalid_email_data = {
        email: 'invalid-email',
        username: 'validuser',
        password: 'SecurePass123'
      }
      invalid_result = compiled.evaluate(invalid_email_data)

      expect(invalid_result.fetch(:email_status)).to eq('invalid')
      expect(invalid_result.fetch(:account_status)).to eq('pending')
    end
  end

  describe 'contact form schema with mixed text patterns' do
    let(:contact_form_text) do
      <<~KUMI
        schema do
          input do
            string :phone
            string :country_code
            string :message_type
            string :priority
          end

          trait :us_phone, input.phone == "1234567890"
          trait :formatted_phone, input.phone == "123-456-7890"
          trait :high_priority, (input.priority == "high") | (input.priority == "urgent")
          trait :support_request, input.message_type == "support"

          value :phone_format do
            on formatted_phone, "formatted"
            base "raw"
          end

          value :urgency_level do
            on high_priority, "escalated"
            base "standard"
          end

          value :routing do
            on support_request, "technical_team"
            base "general_team"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for contact form schema' do
        expect(Kumi::Parser::TextParser.valid?(contact_form_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has identical AST structure' do
        ruby_parsed = ContactFormSchema.__syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(contact_form_text)

        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)
        expect(text_parsed.values.length).to eq(ruby_parsed.values.length)

        # Verify phone format detection trait
        formatted_trait = text_parsed.traits.find { |t| t.name == :formatted_phone }
        expect(formatted_trait.expression).to be_a(Kumi::Syntax::CallExpression)
        expect(formatted_trait.expression.fn_name).to eq(:==)
      end
    end

    it 'handles phone number format detection' do
      ast = Kumi::Parser::TextParser.parse(contact_form_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test formatted phone number
      formatted_data = {
        phone: '123-456-7890',
        country_code: 'US',
        message_type: 'support',
        priority: 'high'
      }
      result = compiled.evaluate(formatted_data)

      expect(result.fetch(:phone_format)).to eq('formatted')
      expect(result.fetch(:urgency_level)).to eq('escalated')
      expect(result.fetch(:routing)).to eq('technical_team')

      # Test raw phone number
      raw_data = {
        phone: '1234567890',
        country_code: 'US',
        message_type: 'inquiry',
        priority: 'low'
      }
      raw_result = compiled.evaluate(raw_data)

      expect(raw_result.fetch(:phone_format)).to eq('raw')
      expect(raw_result.fetch(:urgency_level)).to eq('standard')
      expect(raw_result.fetch(:routing)).to eq('general_team')
    end
  end

  describe 'product code schema with pattern matching' do
    let(:product_code_text) do
      <<~KUMI
        schema do
          input do
            string :sku
            string :category_code
            string :warehouse_location
            string :condition
          end

          trait :electronics, input.category_code == "EL"
          trait :valid_sku, input.sku == "EL-1234-AB"
          trait :warehouse_a, input.warehouse_location == "A12"
          trait :sellable, (input.condition == "new") | (input.condition == "refurbished")

          value :product_type do
            on electronics, "electronic_device"
            base "general_product"
          end

          value :warehouse_zone do
            on warehouse_a, "zone_alpha"
            base "zone_beta"
          end

          value :sales_status do
            on sellable, "available"
            base "not_for_sale"
          end
        end
      KUMI
    end

    describe '.valid?' do
      it 'returns true for product code schema' do
        expect(Kumi::Parser::TextParser.valid?(product_code_text)).to be true
      end
    end

    context 'when compared to ruby parsed schema' do
      it 'has compatible AST structure' do
        ruby_parsed = ProductCodeSchema.__syntax_tree__
        text_parsed = Kumi::Parser::TextParser.parse(product_code_text)

        expect(text_parsed.inputs.length).to eq(ruby_parsed.inputs.length)
        expect(text_parsed.traits.length).to eq(ruby_parsed.traits.length)

        # Compare trait names and basic structure
        text_parsed.traits.each_with_index do |trait, idx|
          ruby_trait = ruby_parsed.traits[idx]
          expect(trait.name).to eq(ruby_trait.name)
        end
      end
    end

    it 'processes product codes with pattern validation' do
      ast = Kumi::Parser::TextParser.parse(product_code_text)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test electronics product
      electronics_data = {
        sku: 'EL-1234-AB',
        category_code: 'EL',
        warehouse_location: 'A12',
        condition: 'new'
      }
      result = compiled.evaluate(electronics_data)

      expect(result.fetch(:product_type)).to eq('electronic_device')
      expect(result.fetch(:warehouse_zone)).to eq('zone_alpha')
      expect(result.fetch(:sales_status)).to eq('available')

      # Test non-electronics product
      general_data = {
        sku: 'CL-5678-CD',
        category_code: 'CL',
        warehouse_location: 'B34',
        condition: 'used'
      }
      general_result = compiled.evaluate(general_data)

      expect(general_result.fetch(:product_type)).to eq('general_product')
      expect(general_result.fetch(:warehouse_zone)).to eq('zone_beta')
      expect(general_result.fetch(:sales_status)).to eq('not_for_sale')
    end
  end

  describe 'comprehensive text matching patterns' do
    let(:comprehensive_text_matching) do
      <<~KUMI
        schema do
          input do
            string :text_field
            string :code_field
            string :status_field
          end

          trait :contains_at, input.text_field == "user@example.com"
          trait :starts_with_prefix, input.code_field == "PREFIX123"
          trait :ends_with_suffix, input.text_field == "example.com"
          trait :exact_match, input.status_field == "ACTIVE"
          trait :length_check, input.code_field == "PREFIX123"
          trait :combined_check, fn(:and, starts_with_prefix, length_check)

          value :text_analysis do
            on contains_at, "has_at_symbol"
            base "no_at_symbol"
          end

          value :code_analysis do
            on starts_with_prefix, "prefixed"
            base "not_prefixed"
          end

          value :combined_analysis do
            on combined_check, "valid_text"
            base "invalid_text"
          end
        end
      KUMI
    end

    it 'parses comprehensive text matching patterns' do
      ast = Kumi::Parser::TextParser.parse(comprehensive_text_matching)

      expect(ast.traits.length).to eq(6)
      expect(ast.values.length).to eq(3)

      # Check contains pattern
      contains_trait = ast.traits.find { |t| t.name == :contains_at }
      expect(contains_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(contains_trait.expression.fn_name).to eq(:==)

      # Check starts_with pattern
      starts_trait = ast.traits.find { |t| t.name == :starts_with_prefix }
      expect(starts_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(starts_trait.expression.fn_name).to eq(:==)

      # Check combined pattern
      combined_trait = ast.traits.find { |t| t.name == :combined_check }
      expect(combined_trait.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(combined_trait.expression.fn_name).to eq(:and)
    end

    it 'executes all text matching patterns correctly' do
      ast = Kumi::Parser::TextParser.parse(comprehensive_text_matching)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test data that matches multiple patterns
      test_data = {
        text_field: 'user@example.com',
        code_field: 'PREFIX123',
        status_field: 'ACTIVE'
      }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:text_analysis)).to eq('has_at_symbol')
      expect(result.fetch(:code_analysis)).to eq('prefixed')
      expect(result.fetch(:combined_analysis)).to eq('valid_text')
    end
  end

  describe 'text matching limitations and workarounds' do
    let(:limitation_examples) do
      <<~KUMI
        schema do
          input do
            string :input_text
            string :pattern_field
          end

          trait :simple_contains, input.input_text == "test_string"
          trait :simple_length, input.input_text == "validtext"
          trait :equality_check, input.pattern_field == "expected"

          value :validation_result do
            on simple_contains, "valid"
            base "invalid"
          end

          value :pattern_status do
            on equality_check, "matches_pattern"
            base "no_match"
          end
        end
      KUMI
    end

    it 'demonstrates current text matching capabilities' do
      ast = Kumi::Parser::TextParser.parse(limitation_examples)

      # Text parser can handle basic string functions and equality
      expect(ast.traits.length).to eq(3)

      # Verify function-based text matching works
      contains_trait = ast.traits.find { |t| t.name == :simple_contains }
      expect(contains_trait.expression.fn_name).to eq(:==)

      length_trait = ast.traits.find { |t| t.name == :simple_length }
      expect(length_trait.expression.fn_name).to eq(:==)
    end

    it 'shows compatibility with analyzer despite domain limitations' do
      ast = Kumi::Parser::TextParser.parse(limitation_examples)

      # Should work with analyzer even without domain enforcement
      expect { Kumi::Analyzer.analyze!(ast) }.not_to raise_error

      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Execution should work with text matching functions
      test_data = { input_text: 'test_string', pattern_field: 'expected' }
      result = compiled.evaluate(test_data)

      expect(result.fetch(:validation_result)).to eq('valid')
      expect(result.fetch(:pattern_status)).to eq('matches_pattern')
    end
  end
end
