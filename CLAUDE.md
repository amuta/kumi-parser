# Kumi Parser - Technical Context

## Current Architecture (January 2025)

## Key Files

- `lib/kumi/parser/smart_tokenizer.rb` - Tokenizer with context tracking
- `lib/kumi/parser/direct_parser.rb` - Parser implementation (renamed from direct_ast_parser.rb)
- `lib/kumi/parser/token_metadata.rb` - Token types and metadata
- `lib/kumi/parser/text_parser.rb` - Public API maintaining compatibility
- `lib/kumi/parser/base.rb` - Core parsing interface
- `lib/kumi/parser/syntax_validator.rb` - Validation with proper diagnostics
- `lib/kumi/parser/errors.rb` - Custom error types

## Important Syntax Rules

- **Functions**: `fn(:symbol, args...)` only (no dot notation like `fn.max()`)
- **Operators**: Standard precedence (*/% > +- > comparisons > & > |)
- **Array access**: Uses `array[index]` syntax (converted to `:at` function internally)
- **Equality**: `==` and `!=` operators (converted from `:eq`/`:ne` tokens)
- **Multi-line expressions**: Parser skips newlines within expressions
- **Cascade**: `value :name do ... on condition, result ... base result ... end`
- **Constants**: Text parser cannot resolve Ruby constants - use inline values

## AST Structure & Compatibility

All nodes from `Kumi::Syntax::*` (defined in main kumi gem):
- `Root(inputs, attributes, traits)`
- `InputDeclaration(name, domain, type, children)`
- `ValueDeclaration(name, expression)`
- `TraitDeclaration(name, expression)`
- `CallExpression(fn_name, args)`
- `InputReference(name)` / `InputElementReference(path)`
- `DeclarationReference(name)`
- `Literal(value)`
- `CascadeExpression(cases)` / `CaseExpression(condition, result)`
- `ArrayExpression(elements)`

**Ruby DSL Compatibility**:
- Cascade conditions: Simple trait references wrapped in `all?([trait])` function calls
- Array access: `[index]` becomes `CallExpression(:at, [array, index])`
- Operators: `:eq` → `:==`, `:ne` → `:!=` for consistency
- Constants: Ruby constants resolved to values in DSL, remain as `DeclarationReference` in text parser

## Debugging & Testing

**View AST structure**:
```ruby
ast = Kumi::Parser::TextParser.parse(schema)
puts Kumi::Support::SExpressionPrinter.print(ast)
# => (Root
#      inputs: [(InputDeclaration :income :float)]
#      attributes: [(ValueDeclaration :tax (CallExpression :+ ...))]
#      traits: [(TraitDeclaration :adult (CallExpression :>= ...))])
```

**Quick validation test**:
```ruby
ruby -r./lib/kumi/parser/text_parser -e "p Kumi::Parser::TextParser.valid?('schema do input do float :x end end')"
```

**Compare with Ruby DSL**:
```ruby
# Define schema in Ruby
module TestSchema
  extend Kumi::Schema
  schema do
    input do
      float :income
    end
    value :tax, fn(:calc, input.income)
  end
end

# Parse equivalent text
text_ast = Kumi::Parser::TextParser.parse(<<~KUMI)
  schema do
    input do
      float :income
    end
    value :tax, fn(:calc, input.income)
  end
KUMI

# Compare ASTs
ruby_ast = TestSchema.__syntax_tree__
text_ast == ruby_ast # Should be true
```

- Tax schema in `spec/kumi/parser/text_parser_example tax_schema_spec.rb` is canonical test
- Run all tests: `rspec spec/kumi/parser/` 
- Integration tests: `rspec spec/kumi/parser/text_parser_integration_spec.rb`

## Error Handling & Validation

- **Parse errors**: `Kumi::Parser::Errors::ParseError` (internal) → `Kumi::Errors::SyntaxError` (public API)
- **Tokenizer errors**: `Kumi::Parser::Errors::TokenizerError` with location info
- **Diagnostics**: Use `SyntaxValidator` for detailed error reporting with line/column info
- **Location tracking**: All tokens and AST nodes include `Kumi::Syntax::Location(file, line, column)`

## Test Status (January 2025)

✅ **All specs passing**: 32 examples, 0 failures, 1 pending
- ✅ Syntax validation with proper diagnostics
- ✅ AST compatibility with Ruby DSL (when constants aren't used)
- ✅ Integration with analyzer and compiler
- ✅ End-to-end execution testing
- ✅ Error type compatibility

## Known Limitations

- **Ruby constants**: Text parser cannot resolve Ruby constants like `CONST_NAME` - use inline values instead
- **Domain specification**: Parsing not fully implemented
- **Diagnostic APIs**: Monaco/CodeMirror/JSON format methods not implemented

## Performance

- Tokenization: <1ms for typical schemas
- Parsing: ~4ms for complete tax schema (21 values, 4 traits)
- Direct AST construction eliminates transformation overhead