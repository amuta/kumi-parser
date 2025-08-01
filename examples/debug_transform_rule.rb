# Debug specific transform rule

require_relative 'lib/kumi/text_parser'

# Test just the trait parsing
trait_text = 'trait :adult, input.age >= 18'

grammar = Kumi::TextParser::Grammar.new
transform = Kumi::TextParser::Transform.new

begin
  # Parse just the trait declaration
  parse_result = grammar.trait_declaration.parse(trait_text)
  puts 'Trait parse result:'
  puts parse_result.inspect
  puts

  # Try to transform it
  transformed = transform.apply(parse_result)
  puts 'Transformed result:'
  puts transformed.inspect
  puts "Class: #{transformed.class}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
