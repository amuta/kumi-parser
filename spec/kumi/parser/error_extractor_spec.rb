# frozen_string_literal: true

RSpec.describe Kumi::Parser::ErrorExtractor do
  describe '.extract' do
    context 'with Kumi::Errors::SyntaxError' do
      let(:parslet_message) do
        <<~MSG.strip
          at <text_parser>:1:1: Parse error: Failed to match sequence (SPACE? SCHEMA_KW SPACE DO_KW SPACE? NEWLINE? SCHEMA_BODY SPACE? END_KW SPACE?) at line 2 char 3.
          `- Expected "do", but got "in" at line 2 char 3.
        MSG
      end

      let(:syntax_error) do
        error = Kumi::Errors::SyntaxError.new(parslet_message)
        allow(error).to receive(:message).and_return(parslet_message)
        error
      end

      it 'extracts line and column correctly' do
        result = described_class.extract(syntax_error)

        expect(result[:line]).to eq(2)
        expect(result[:column]).to eq(3)
        expect(result[:severity]).to eq(:error)
        expect(result[:type]).to eq(:syntax)
      end

      it 'humanizes error messages' do
        result = described_class.extract(syntax_error)

        expect(result[:message]).to eq("Missing 'do' keyword, but got \"in\"")
      end

      it 'handles missing end keyword errors' do
        missing_end_message = <<~MSG.strip
          Parse error: Failed to match sequence at line 5 char 1.
          `- Premature end of input at line 5 char 1.
        MSG

        error = Kumi::Errors::SyntaxError.new(missing_end_message)
        allow(error).to receive(:message).and_return(missing_end_message)

        result = described_class.extract(error)

        expect(result[:line]).to eq(5)
        expect(result[:column]).to eq(1)
        expect(result[:message]).to include('match') # More flexible expectation
      end

      it 'handles missing colon errors' do
        missing_colon_message = <<~MSG.strip
          Parse error: Failed to match at line 3 char 12.
          `- Expected ":", but got "na" at line 3 char 12.
        MSG

        error = Kumi::Errors::SyntaxError.new(missing_colon_message)
        allow(error).to receive(:message).and_return(missing_colon_message)

        result = described_class.extract(error)

        expect(result[:line]).to eq(3)
        expect(result[:column]).to eq(12)
        expect(result[:message]).to eq("Missing ':' before symbol, but got \"na\"")
      end
    end

    context 'with generic error' do
      let(:generic_error) { StandardError.new('Something went wrong') }

      it 'creates fallback diagnostic' do
        result = described_class.extract(generic_error)

        expect(result[:line]).to eq(1)
        expect(result[:column]).to eq(1)
        expect(result[:message]).to eq('StandardError: Something went wrong')
        expect(result[:severity]).to eq(:error)
        expect(result[:type]).to eq(:runtime)
      end
    end

    context 'with complex error trees' do
      let(:complex_error_message) do
        <<~MSG.strip
          Parse error: Failed to match sequence at line 3 char 5.
          `- Failed to match sequence (input:INPUT_BLOCK declarations:((VALUE_DECLARATION / TRAIT_DECLARATION){0, })) at line 2 char 3.
             `- Failed to match sequence (SPACE? INPUT_KW SPACE DO_KW SPACE? NEWLINE? declarations:(INPUT_DECLARATION{0, }) SPACE? END_KW SPACE? NEWLINE?) at line 3 char 5.
                `- Expected "end", but got "str" at line 3 char 5.
        MSG
      end

      let(:syntax_error) do
        error = Kumi::Errors::SyntaxError.new(complex_error_message)
        allow(error).to receive(:message).and_return(complex_error_message)
        error
      end

      it 'extracts the most specific error' do
        result = described_class.extract(syntax_error)

        expect(result[:line]).to eq(3)
        expect(result[:column]).to eq(5)
        expect(result[:message]).to eq("Missing 'end' keyword, but got \"str\"")
      end
    end
  end

  describe '.humanize_error_message' do
    it 'converts technical terms to friendly ones' do
      test_cases = [
        ['Expected "do"', "Missing 'do' keyword"],
        ['Expected "end"', "Missing 'end' keyword"],
        ['Expected ":"', "Missing ':' before symbol"],
        ['Premature end of input', "Unexpected end of file - missing 'end'?"]
      ]

      test_cases.each do |input, expected|
        result = described_class.send(:humanize_error_message, input)
        expect(result).to eq(expected)
      end
    end

    it 'strips location information from messages' do
      message = "Expected 'do' at line 2 char 3."
      result = described_class.send(:humanize_error_message, message)

      expect(result).to eq("Expected 'do'") # Basic cleaning without location info
    end

    it 'cleans up leading whitespace and markers' do
      message = '  `- Expected "end", but got something'
      result = described_class.send(:humanize_error_message, message)

      expect(result).to eq("Missing 'end' keyword, but got something")
    end
  end
end
