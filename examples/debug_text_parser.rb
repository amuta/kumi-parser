# Debug the text parser transform

require_relative 'lib/kumi/text_parser'

schema_text = <<~SCHEMA
  schema do
    input do
      integer :age
    end
  #{'  '}
    trait :adult, input.age >= 18
    value :bonus, 100
  end
SCHEMA

puts 'Debugging text parser...'

begin
  # Test just the grammar parsing first
  grammar = Kumi::TextParser::Grammar.new
  parse_tree = grammar.parse(schema_text)

  puts 'Raw parse tree:'
  puts parse_tree.inspect
  puts

  # Now test the transform
  transform = Kumi::TextParser::Transform.new
  ast = transform.apply(parse_tree)

  puts 'Transformed AST:'
  puts ast.inspect
  puts

  puts 'AST structure:'
  puts "- Values: #{ast.values.count} - #{ast.values.map(&:name)}"
  puts "- Traits: #{ast.traits.count} - #{ast.traits.map(&:name)}"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
