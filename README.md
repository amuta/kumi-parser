# Kumi::Parser

Text parser for [Kumi](https://github.com/amuta/kumi) schemas. Direct tokenizer → AST construction with ~4ms parse time.

## Installation

```ruby
gem 'kumi-parser'
```

## Usage

```ruby
require 'kumi/parser'

schema = <<~KUMI
  schema do
    input do
      float :income
      string :status
    end
    
    trait :adult, input.age >= 18
    value :tax, fn(:calculate_tax, input.income)
  end
KUMI

# Parse to AST
ast = Kumi::Parser::TextParser.parse(schema)

# Validate
Kumi::Parser::TextParser.valid?(schema) # => true
```

## API

- `parse(text)` → AST
- `valid?(text)` → Boolean  
- `validate(text)` → Array of error hashes

## Syntax

```
schema do
  input do
    <type> :<name>[, domain: <spec>]
  end
  
  trait :<name>, <expression>
  
  value :<name>, <expression>
  value :<name> do
    on <condition>, <result>
    base <result>
  end
end
```

**Function calls**: `fn(:name, arg1, arg2, ...)`  
**Operators**: `+` `-` `*` `**` `` `/` `%` `>` `<` `>=` `<=` `==` `!=` `&` `|`  
**References**: `input.field`, `value_name`, `array[index]`  
**Strings**: Both `"double"` and `'single'` quotes supported  
**Element syntax**: `element :type, :name` for array element specifications

## Ruby DSL Differences

**String concatenation**: Ruby DSL evaluates `"Hello" + "World"` → `Literal("HelloWorld")`, text parser → `CallExpression(:add, [...])`.

**Semantically equivalent** - both should execute identically.

## Architecture

- `smart_tokenizer.rb` - Context-aware tokenization with embedded metadata
- `direct_ast_parser.rb` - Recursive descent parser, direct AST construction
- `token_metadata.rb` - Token types, precedence, and semantic hints

## License

MIT