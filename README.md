# Kumi::Parser

Text parser for [Kumi](https://github.com/amuta/kumi). Allows Kumi schemas to be written as plain text with syntax validation and editor integration.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kumi-parser'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install kumi-parser

## Usage

### Basic Parsing

```ruby
require 'kumi/parser'

schema_text = <<~SCHEMA
  schema do
    input do
      integer :age, domain: 18..65
      string :status, domain: %w[active inactive]
    end
    
    trait :adult, input.age >= 18
    value :bonus, 100
  end
SCHEMA

# Parse and get AST
ast = Kumi::Parser::TextParser.parse(schema_text)

# Validate syntax
diagnostics = Kumi::Parser::TextParser.validate(schema_text)
puts "Valid!" if diagnostics.empty?
```

### Editor Integration

```ruby
# Get diagnostics for Monaco Editor
monaco_diagnostics = Kumi::Parser::TextParser.diagnostics_for_monaco(schema_text)

# Get diagnostics for CodeMirror
codemirror_diagnostics = Kumi::Parser::TextParser.diagnostics_for_codemirror(schema_text)

# Get diagnostics as JSON
json_diagnostics = Kumi::Parser::TextParser.diagnostics_as_json(schema_text)
```

## API Reference

- `parse(text)` - Parse schema text and return AST
- `validate(text)` - Validate syntax and return diagnostics
- `valid?(text)` - Quick validation check (returns boolean)
- `diagnostics_for_monaco(text)` - Get Monaco Editor format diagnostics
- `diagnostics_for_codemirror(text)` - Get CodeMirror format diagnostics  
- `diagnostics_as_json(text)` - Get JSON format diagnostics

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## License

MIT License