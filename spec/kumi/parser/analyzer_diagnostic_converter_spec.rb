# frozen_string_literal: true

RSpec.describe Kumi::Parser::AnalyzerDiagnosticConverter do
  describe '.convert_errors' do
    context 'with error entry objects' do
      let(:mock_location) { double('Location', line: 5, column: 10) }
      let(:error_entry) do
        double('ErrorEntry',
               message: "Undefined reference 'foo'",
               location: mock_location,
               type: :semantic)
      end

      it 'converts error entries to diagnostics' do
        diagnostics = described_class.convert_errors([error_entry])

        expect(diagnostics.count).to eq(1)
        diagnostic = diagnostics.to_a.first

        expect(diagnostic.line).to eq(5)
        expect(diagnostic.column).to eq(10)
        expect(diagnostic.message).to eq("Undefined reference 'foo'")
        expect(diagnostic.severity).to eq(:error)
        expect(diagnostic.type).to eq(:semantic)
      end

      it 'maps different error types to appropriate severities' do
        test_cases = [
          %i[syntax error],
          %i[semantic error],
          %i[type error],
          %i[runtime error],
          %i[warning warning],
          %i[info info],
          %i[hint hint],
          %i[unknown error]
        ]

        test_cases.each do |error_type, expected_severity|
          error = double('ErrorEntry',
                         message: 'Test error',
                         location: mock_location,
                         type: error_type)

          diagnostics = described_class.convert_errors([error])
          diagnostic = diagnostics.to_a.first

          expect(diagnostic.severity).to eq(expected_severity)
          expect(diagnostic.type).to eq(error_type)
        end
      end
    end

    context 'with legacy array format' do
      let(:mock_location) { double('Location', line: 3, column: 7) }
      let(:legacy_error) { [mock_location, 'Type mismatch error'] }

      it 'converts legacy format to diagnostics' do
        diagnostics = described_class.convert_errors([legacy_error])

        expect(diagnostics.count).to eq(1)
        diagnostic = diagnostics.to_a.first

        expect(diagnostic.line).to eq(3)
        expect(diagnostic.column).to eq(7)
        expect(diagnostic.message).to eq('Type mismatch error')
        expect(diagnostic.severity).to eq(:error)
        expect(diagnostic.type).to eq(:semantic)
      end
    end

    context 'with symbol locations' do
      let(:error_entry) do
        double('ErrorEntry',
               message: 'Symbol location error',
               location: :unknown,
               type: :semantic)
      end

      it 'handles symbol locations with fallback' do
        diagnostics = described_class.convert_errors([error_entry])

        diagnostic = diagnostics.to_a.first
        expect(diagnostic.line).to eq(1)
        expect(diagnostic.column).to eq(1)
        expect(diagnostic.message).to eq('Symbol location error')
      end
    end

    context 'with unknown error format' do
      let(:unknown_error) { 'Some random error string' }

      it 'handles unknown errors gracefully' do
        diagnostics = described_class.convert_errors([unknown_error])

        diagnostic = diagnostics.to_a.first
        expect(diagnostic.line).to eq(1)
        expect(diagnostic.column).to eq(1)
        expect(diagnostic.message).to include('Unknown analyzer error')
        expect(diagnostic.severity).to eq(:error)
        expect(diagnostic.type).to eq(:semantic)
      end
    end

    context 'with mixed error types' do
      let(:mock_location1) { double('Location', line: 2, column: 5) }
      let(:mock_location2) { double('Location', line: 7, column: 12) }

      let(:error1) do
        double('ErrorEntry',
               message: 'First error',
               location: mock_location1,
               type: :semantic)
      end

      let(:error2) { [mock_location2, 'Second error'] }
      let(:error3) { 'Unknown error' }

      it 'converts all error types in a single collection' do
        errors = [error1, error2, error3]
        diagnostics = described_class.convert_errors(errors)

        expect(diagnostics.count).to eq(3)

        # Check first error (ErrorEntry)
        first_diagnostic = diagnostics.to_a[0]
        expect(first_diagnostic.message).to eq('First error')
        expect(first_diagnostic.line).to eq(2)

        # Check second error (legacy array)
        second_diagnostic = diagnostics.to_a[1]
        expect(second_diagnostic.message).to eq('Second error')
        expect(second_diagnostic.line).to eq(7)

        # Check third error (unknown)
        third_diagnostic = diagnostics.to_a[2]
        expect(third_diagnostic.message).to include('Unknown analyzer error')
        expect(third_diagnostic.line).to eq(1)
      end
    end

    context 'with empty error list' do
      it 'returns empty diagnostic collection' do
        diagnostics = described_class.convert_errors([])
        expect(diagnostics).to be_empty
        expect(diagnostics.count).to eq(0)
      end
    end
  end

  describe 'private methods' do
    describe '.extract_location' do
      it 'extracts from location objects' do
        location = double('Location', line: 10, column: 20)
        result = described_class.send(:extract_location, location)

        expect(result[:line]).to eq(10)
        expect(result[:column]).to eq(20)
      end

      it 'handles symbol locations' do
        result = described_class.send(:extract_location, :unknown)

        expect(result[:line]).to eq(1)
        expect(result[:column]).to eq(1)
      end

      it 'handles nil locations' do
        result = described_class.send(:extract_location, nil)

        expect(result[:line]).to eq(1)
        expect(result[:column]).to eq(1)
      end
    end
  end
end
