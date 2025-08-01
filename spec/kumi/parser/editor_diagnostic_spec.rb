# frozen_string_literal: true

RSpec.describe Kumi::Parser::TextParser::EditorDiagnostic do
  let(:diagnostic) do
    described_class.new(
      line: 5,
      column: 10,
      message: "Missing 'do' keyword",
      severity: :error,
      type: :syntax
    )
  end

  describe '#initialize' do
    it 'sets all attributes correctly' do
      expect(diagnostic.line).to eq(5)
      expect(diagnostic.column).to eq(10)
      expect(diagnostic.message).to eq("Missing 'do' keyword")
      expect(diagnostic.severity).to eq(:error)
      expect(diagnostic.type).to eq(:syntax)
    end

    it 'uses default values for optional parameters' do
      basic_diagnostic = described_class.new(line: 1, column: 1, message: 'Test')

      expect(basic_diagnostic.severity).to eq(:error)
      expect(basic_diagnostic.type).to eq(:syntax)
    end
  end

  describe '#to_monaco' do
    it 'converts to Monaco Editor format' do
      result = diagnostic.to_monaco

      expect(result).to eq({
                             severity: 8, # Monaco.MarkerSeverity.Error
                             message: "Missing 'do' keyword",
                             startLineNumber: 5,
                             startColumn: 10,
                             endLineNumber: 5,
                             endColumn: 11
                           })
    end

    it 'handles different severity levels' do
      warning_diagnostic = described_class.new(
        line: 1, column: 1, message: 'Warning', severity: :warning
      )

      result = warning_diagnostic.to_monaco
      expect(result[:severity]).to eq(4) # Monaco.MarkerSeverity.Warning
    end

    it 'handles info severity' do
      info_diagnostic = described_class.new(
        line: 1, column: 1, message: 'Info', severity: :info
      )

      result = info_diagnostic.to_monaco
      expect(result[:severity]).to eq(2) # Monaco.MarkerSeverity.Info
    end

    it 'defaults unknown severity to error' do
      unknown_diagnostic = described_class.new(
        line: 1, column: 1, message: 'Unknown', severity: :unknown
      )

      result = unknown_diagnostic.to_monaco
      expect(result[:severity]).to eq(8) # Monaco.MarkerSeverity.Error
    end
  end

  describe '#to_codemirror' do
    it 'converts to CodeMirror format' do
      result = diagnostic.to_codemirror

      expect(result).to eq({
                             from: 4009, # (line-1) * 1000 + (column-1)
                             to: 4010, # (line-1) * 1000 + column
                             severity: 'error',
                             message: "Missing 'do' keyword"
                           })
    end

    it 'converts severity to string' do
      warning_diagnostic = described_class.new(
        line: 2, column: 5, message: 'Warning', severity: :warning
      )

      result = warning_diagnostic.to_codemirror
      expect(result[:severity]).to eq('warning')
    end
  end

  describe '#to_h' do
    it 'converts to hash format' do
      result = diagnostic.to_h

      expect(result).to eq({
                             line: 5,
                             column: 10,
                             message: "Missing 'do' keyword",
                             severity: 'error',
                             type: 'syntax'
                           })
    end
  end

  describe '#to_json' do
    it 'converts to JSON string' do
      result = diagnostic.to_json

      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed).to eq({
                             'line' => 5,
                             'column' => 10,
                             'message' => "Missing 'do' keyword",
                             'severity' => 'error',
                             'type' => 'syntax'
                           })
    end
  end
end

RSpec.describe Kumi::Parser::TextParser::DiagnosticCollection do
  let(:diagnostic1) do
    Kumi::Parser::TextParser::EditorDiagnostic.new(
      line: 2, column: 3, message: 'Error 1', severity: :error
    )
  end

  let(:diagnostic2) do
    Kumi::Parser::TextParser::EditorDiagnostic.new(
      line: 5, column: 8, message: 'Warning 1', severity: :warning
    )
  end

  let(:collection) { described_class.new([diagnostic1, diagnostic2]) }

  describe '#initialize' do
    it 'accepts array of diagnostics' do
      expect(collection.count).to eq(2)
    end

    it 'defaults to empty array' do
      empty_collection = described_class.new
      expect(empty_collection).to be_empty
      expect(empty_collection.count).to eq(0)
    end
  end

  describe '#<<' do
    it 'adds diagnostic to collection' do
      collection = described_class.new
      collection << diagnostic1

      expect(collection.count).to eq(1)
      expect(collection).not_to be_empty
    end
  end

  describe '#to_monaco' do
    it 'converts all diagnostics to Monaco format' do
      result = collection.to_monaco

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first).to have_key(:severity)
      expect(result.first).to have_key(:startLineNumber)
    end
  end

  describe '#to_codemirror' do
    it 'converts all diagnostics to CodeMirror format' do
      result = collection.to_codemirror

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first).to have_key(:from)
      expect(result.first).to have_key(:to)
      expect(result.first).to have_key(:severity)
    end
  end

  describe '#to_json' do
    it 'converts all diagnostics to JSON' do
      result = collection.to_json

      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed).to be_an(Array)
      expect(parsed.length).to eq(2)
    end
  end

  describe '#to_a' do
    it 'returns array of diagnostics' do
      result = collection.to_a

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first).to be_a(Kumi::Parser::TextParser::EditorDiagnostic)
    end
  end

  describe '#empty?' do
    it 'returns true for empty collection' do
      empty_collection = described_class.new
      expect(empty_collection).to be_empty
    end

    it 'returns false for non-empty collection' do
      expect(collection).not_to be_empty
    end
  end

  describe '#count' do
    it 'returns number of diagnostics' do
      expect(collection.count).to eq(2)
    end
  end
end
