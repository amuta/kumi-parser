#!/usr/bin/env ruby
# Basic functionality test for kumi-parser

require_relative 'lib/kumi/parser'

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

puts 'Testing kumi-parser...'
puts '=' * 40

begin
  # Test validation
  puts '1. Testing validation...'
  diagnostics = Kumi::Parser::TextParser.validate(schema_text)
  puts "   ✅ Validation: #{diagnostics.empty? ? 'PASSED' : 'FAILED'}"

  unless diagnostics.empty?
    diagnostics.to_a.each do |d|
      puts "   Error: Line #{d.line}, Column #{d.column}: #{d.message}"
    end
  end

  # Test parsing if validation passed
  if diagnostics.empty?
    puts '2. Testing parsing...'
    ast = Kumi::Parser::TextParser.parse(schema_text)
    puts "   ✅ Parsing: #{ast ? 'PASSED' : 'FAILED'}"
    puts "   AST type: #{ast.class}"
  end

  puts "\n🎉 Basic functionality test completed!"
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
