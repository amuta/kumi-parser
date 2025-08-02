# frozen_string_literal: true

module Kumi
  module Parser
    # Token with embedded metadata for smart parsing
    class Token
      attr_reader :type, :value, :location, :metadata

      def initialize(type, value, location, metadata = {})
        @type = type
        @value = value
        @location = location
        @metadata = metadata
      end

      # Semantic predicates embedded in token
      def keyword?
        @metadata[:category] == :keyword
      end

      def operator?
        @metadata[:category] == :operator
      end

      def literal?
        @metadata[:category] == :literal
      end

      def identifier?
        @metadata[:category] == :identifier
      end

      def punctuation?
        @metadata[:category] == :punctuation
      end

      # Operator precedence embedded in token
      def precedence
        @metadata[:precedence] || 0
      end

      def left_associative?
        @metadata[:associativity] == :left
      end

      def right_associative?
        @metadata[:associativity] == :right
      end

      # Parser hints embedded in token
      def expects_block?
        @metadata[:expects_block] == true
      end

      def terminates_expression?
        @metadata[:terminates_expression] == true
      end

      def starts_expression?
        @metadata[:starts_expression] == true
      end

      # Direct AST construction hint
      def ast_class
        @metadata[:ast_class]
      end

      def to_s
        "#{@type}(#{@value.inspect}) at #{@location}"
      end

      def inspect
        to_s
      end

      def ==(other)
        other.is_a?(Token) &&
          @type == other.type &&
          @value == other.value &&
          @location == other.location
      end
    end
  end
end