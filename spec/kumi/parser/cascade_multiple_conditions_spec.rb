# frozen_string_literal: true

RSpec.describe 'Cascade Multiple Conditions' do
  describe 'parsing multiple comma-separated conditions' do
    it 'parses single condition (existing behavior)' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
          end
          
          trait :positive, input.x > 0

          value :status do
            on positive, "positive"
            base "not positive"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      status_value = ast.values.find { |v| v.name == :status }
      
      expect(status_value.expression).to be_a(Kumi::Syntax::CascadeExpression)
      cases = status_value.expression.cases
      expect(cases.length).to eq(2)

      # Single condition case
      first_case = cases[0]
      expect(first_case.condition).to be_a(Kumi::Syntax::CallExpression)
      expect(first_case.condition.fn_name).to eq(:cascade_and)
      expect(first_case.condition.args.length).to eq(1)
      expect(first_case.result.value).to eq("positive")
    end

    it 'parses two conditions separated by comma' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y
          end
          
          trait :x_positive, input.x > 0
          trait :y_positive, input.y > 0

          value :status do
            on x_positive, y_positive, "both positive"
            base "not both positive"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      status_value = ast.values.find { |v| v.name == :status }
      cases = status_value.expression.cases

      # Two conditions case
      first_case = cases[0]
      expect(first_case.condition).to be_a(Kumi::Syntax::CallExpression)
      expect(first_case.condition.fn_name).to eq(:cascade_and)
      expect(first_case.condition.args.length).to eq(2)
      
      # Check individual conditions
      expect(first_case.condition.args[0]).to be_a(Kumi::Syntax::DeclarationReference)
      expect(first_case.condition.args[0].name).to eq(:x_positive)
      expect(first_case.condition.args[1]).to be_a(Kumi::Syntax::DeclarationReference)
      expect(first_case.condition.args[1].name).to eq(:y_positive)
      
      expect(first_case.result.value).to eq("both positive")
    end

    it 'parses three conditions separated by commas' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y
            integer :z
          end
          
          trait :x_positive, input.x > 0
          trait :y_positive, input.y > 0
          trait :z_positive, input.z > 0

          value :status do
            on x_positive, y_positive, z_positive, "all positive"
            base "not all positive"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      status_value = ast.values.find { |v| v.name == :status }
      cases = status_value.expression.cases

      # Three conditions case
      first_case = cases[0]
      expect(first_case.condition).to be_a(Kumi::Syntax::CallExpression)
      expect(first_case.condition.fn_name).to eq(:cascade_and)
      expect(first_case.condition.args.length).to eq(3)
      expect(first_case.result.value).to eq("all positive")
    end

    it 'handles mixed single and multiple conditions in same cascade' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y
          end
          
          trait :x_positive, input.x > 0
          trait :y_positive, input.y > 0

          value :status do
            on x_positive, y_positive, "both positive"
            on x_positive, "x only positive"  
            on y_positive, "y only positive"
            base "neither positive"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      status_value = ast.values.find { |v| v.name == :status }
      cases = status_value.expression.cases
      expect(cases.length).to eq(4)

      # Multiple conditions case
      multiple_case = cases[0]
      expect(multiple_case.condition.args.length).to eq(2)
      expect(multiple_case.result.value).to eq("both positive")

      # Single conditions cases
      single_case_1 = cases[1]
      expect(single_case_1.condition.args.length).to eq(1)
      expect(single_case_1.result.value).to eq("x only positive")

      single_case_2 = cases[2]
      expect(single_case_2.condition.args.length).to eq(1)
      expect(single_case_2.result.value).to eq("y only positive")
    end

    it 'works with complex expression results' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y
          end
          
          trait :x_positive, input.x > 0
          trait :y_positive, input.y > 0

          value :status do
            on x_positive, y_positive, fn(:concat, "both", "positive")
            base fn(:concat, "not", "positive")
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      status_value = ast.values.find { |v| v.name == :status }
      cases = status_value.expression.cases

      # Check that result can be a complex expression
      first_case = cases[0]
      expect(first_case.result).to be_a(Kumi::Syntax::CallExpression)
      expect(first_case.result.fn_name).to eq(:concat)
      expect(first_case.result.args[0].value).to eq("both")
      expect(first_case.result.args[1].value).to eq("positive")
    end

    it 'works with complex condition expressions' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y
          end

          value :status do
            on input.x > 0, input.y > 0, "both positive"
            base "not both positive"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      status_value = ast.values.find { |v| v.name == :status }
      cases = status_value.expression.cases

      # Check that conditions can be complex expressions
      first_case = cases[0]
      expect(first_case.condition).to be_a(Kumi::Syntax::CallExpression)
      expect(first_case.condition.fn_name).to eq(:cascade_and)
      expect(first_case.condition.args.length).to eq(2)
      
      # Both conditions should be comparison expressions
      first_case.condition.args.each do |condition|
        expect(condition).to be_a(Kumi::Syntax::CallExpression)
        expect(condition.fn_name).to eq(:>)
      end
    end
  end

  describe 'integration with analyzer and compiler' do
    it 'executes multiple conditions correctly' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y
          end
          
          trait :x_positive, input.x > 0
          trait :y_positive, input.y > 0

          value :status do
            on x_positive, y_positive, "both positive"
            on x_positive, "x positive"  
            on y_positive, "y positive"
            base "neither positive"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      
      # Analyze and compile
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # Test all combinations
      test_cases = [
        { input: { x: 1, y: 1 }, expected: "both positive" },
        { input: { x: 1, y: -1 }, expected: "x positive" },
        { input: { x: -1, y: 1 }, expected: "y positive" },
        { input: { x: -1, y: -1 }, expected: "neither positive" }
      ]
      
      test_cases.each do |test_case|
        result = compiled.evaluate(test_case[:input])
        expect(result.fetch(:status)).to eq(test_case[:expected])
      end
    end

    it 'executes three conditions correctly' do
      schema = <<~KUMI
        schema do
          input do
            integer :x
            integer :y  
            integer :z
          end
          
          trait :x_positive, input.x > 0
          trait :y_positive, input.y > 0
          trait :z_positive, input.z > 0

          value :result do
            on x_positive, y_positive, z_positive, "all three positive"
            on x_positive, y_positive, "x and y positive"
            base "other"
          end
        end
      KUMI

      ast = Kumi::Parser::TextParser.parse(schema)
      analysis = Kumi::Analyzer.analyze!(ast)
      compiled = Kumi::Compiler.compile(ast, analyzer: analysis)

      # All three positive
      result = compiled.evaluate({ x: 1, y: 1, z: 1 })
      expect(result.fetch(:result)).to eq("all three positive")

      # Only x and y positive  
      result = compiled.evaluate({ x: 1, y: 1, z: -1 })
      expect(result.fetch(:result)).to eq("x and y positive")

      # Other case
      result = compiled.evaluate({ x: 1, y: -1, z: -1 })
      expect(result.fetch(:result)).to eq("other")
    end
  end
end