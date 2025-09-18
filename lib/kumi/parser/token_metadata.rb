# frozen_string_literal: true

module Kumi
  module Parser
    # Token types
    module TokenType
      # Literals
      INTEGER = :integer
      FLOAT = :float
      STRING = :string
      BOOLEAN = :boolean

      # Identifiers and symbols
      IDENTIFIER = :identifier
      SYMBOL = :symbol           # :name
      CONSTANT = :constant       # Float::INFINITY

      # Keywords
      SCHEMA = :schema
      INPUT = :input
      VALUE = :value
      TRAIT = :trait
      DO = :do
      END_KW = :end
      ON = :on
      BASE = :base

      # Type keywords
      INTEGER_TYPE = :integer_type   # integer
      FLOAT_TYPE = :float_type       # float
      STRING_TYPE = :string_type     # string
      BOOLEAN_TYPE = :boolean_type   # boolean
      ANY_TYPE = :any_type           # any
      ARRAY_TYPE = :array_type       # array
      ELEMENT_TYPE = :element_type   # element

      # Function keywords
      FN = :fn

      # Operators (by precedence)
      EXPONENT = :exponent # **
      MULTIPLY = :multiply # *
      DIVIDE = :divide          # /
      MODULO = :modulo          # %
      ADD = :add                # +
      SUBTRACT = :subtract      # -
      GTE = :gte                # >=
      LTE = :lte                # <=
      GT = :gt                  # >
      LT = :lt                  # <
      EQ = :eq                  # ==
      NE = :ne                  # !=
      AND = :and                # &
      OR = :or                  # |

      # Punctuation
      DOT = :dot                # .
      DOT_DOT = :dot_dot        # ..
      DOT_DOT_DOT = :dot_dot_dot # ...
      COMMA = :comma            # ,
      COLON = :colon            # :
      LPAREN = :lparen          # (
      RPAREN = :rparen          # )
      LBRACKET = :lbracket      # [
      RBRACKET = :rbracket      # ]

      # Special
      NEWLINE = :newline
      EOF = :eof
      COMMENT = :comment # # comment
    end

    # Rich metadata for each token type
    TOKEN_METADATA = {
      # Keywords with parsing hints
      schema: {
        category: :keyword,
        expects_block: true,
        block_terminator: :end
      },
      input: {
        category: :keyword,
        expects_block: true,
        block_terminator: :end,
        context: :input_declarations
      },
      value: {
        category: :keyword,
        expects_expression: true,
        declaration_type: :value
      },
      trait: {
        category: :keyword,
        expects_expression: true,
        declaration_type: :trait
      },
      do: {
        category: :keyword,
        block_opener: true
      },
      end: {
        category: :keyword,
        block_closer: true,
        terminates_expression: true
      },
      on: {
        category: :keyword,
        cascade_keyword: true,
        expects_condition: true
      },
      base: {
        category: :keyword,
        cascade_keyword: true,
        is_base_case: true
      },

      # Type keywords
      integer_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :integer
      },
      float_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :float
      },
      string_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :string
      },
      boolean_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :boolean
      },
      any_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :any
      },
      array_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :array
      },
      hash_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :hash
      },
      element_type: {
        category: :type_keyword,
        starts_declaration: true,
        type_name: :element
      },

      # Function keyword
      fn: {
        category: :keyword,
        function_keyword: true,
        starts_expression: true
      },

      function_sugar: {
        function_keyword: true,
        starts_expression: true
      },

      # Operators with precedence and associativity
      exponent: {
        category: :operator,
        precedence: 7,
        associativity: :right,
        arity: :binary
      },
      multiply: {
        category: :operator,
        precedence: 6,
        associativity: :left,
        arity: :binary
      },
      divide: {
        category: :operator,
        precedence: 6,
        associativity: :left,
        arity: :binary
      },
      modulo: {
        category: :operator,
        precedence: 6,
        associativity: :left,
        arity: :binary
      },
      add: {
        category: :operator,
        precedence: 5,
        associativity: :left,
        arity: :binary
      },
      subtract: {
        category: :operator,
        precedence: 5,
        associativity: :left,
        arity: :binary
      },
      gte: {
        category: :operator,
        precedence: 4,
        associativity: :left,
        arity: :binary,
        returns_boolean: true
      },
      lte: {
        category: :operator,
        precedence: 4,
        associativity: :left,
        arity: :binary,
        returns_boolean: true
      },
      gt: {
        category: :operator,
        precedence: 4,
        associativity: :left,
        arity: :binary,
        returns_boolean: true
      },
      lt: {
        category: :operator,
        precedence: 4,
        associativity: :left,
        arity: :binary,
        returns_boolean: true
      },
      eq: {
        category: :operator,
        precedence: 4,
        associativity: :left,
        arity: :binary,
        returns_boolean: true
      },
      ne: {
        category: :operator,
        precedence: 4,
        associativity: :left,
        arity: :binary,
        returns_boolean: true
      },
      and: {
        category: :operator,
        precedence: 3,
        associativity: :left,
        arity: :binary,
        requires_boolean: true
      },
      or: {
        category: :operator,
        precedence: 2,
        associativity: :left,
        arity: :binary,
        requires_boolean: true
      },
      # Literals with type information
      integer: {
        category: :literal,
        starts_expression: true,
        ast_class: 'Kumi::Syntax::Literal'
      },
      float: {
        category: :literal,
        starts_expression: true,
        ast_class: 'Kumi::Syntax::Literal'
      },
      string: {
        category: :literal,
        starts_expression: true,
        ast_class: 'Kumi::Syntax::Literal'
      },
      boolean: {
        category: :literal,
        starts_expression: true,
        ast_class: 'Kumi::Syntax::Literal'
      },
      # Identifiers and references
      identifier: {
        category: :identifier,
        starts_expression: true,
        can_be_reference: true
      },
      symbol: {
        category: :identifier,
        starts_expression: true,
        is_declaration_name: true
      },
      constant: {
        category: :literal,
        starts_expression: true,
        ast_class: 'Kumi::Syntax::Literal'
      },

      # Punctuation with parser hints
      dot: {
        category: :punctuation,
        indicates_member_access: true
      },
      dot_dot: {
        category: :range
      },
      dot_dot_dot: {
        category: :range
      },
      comma: {
        category: :punctuation,
        separates_items: true
      },
      colon: {
        category: :punctuation,
        indicates_symbol: true
      },
      lparen: {
        category: :punctuation,
        opens_group: true,
        group_closer: :rparen,
        starts_expression: true
      },
      rparen: {
        category: :punctuation,
        closes_group: true,
        terminates_expression: true
      },
      lbracket: {
        category: :punctuation,
        opens_group: true,
        group_closer: :rbracket,
        starts_expression: true,
        indicates_array: true
      },
      rbracket: {
        category: :punctuation,
        closes_group: true,
        terminates_expression: true
      },

      left_brace: {
        category: :punctuation,
        opens_scope: :hash
      },
      right_brace: {
        category: :punctuation,
        closes_scope: :hash
      },

      # Special tokens
      newline: {
        category: :whitespace,
        separates_statements: true
      },
      eof: {
        category: :special,
        terminates_input: true
      },
      comment: {
        category: :whitespace,
        ignored_by_parser: true
      }
    }.freeze

    # Character to token mappings
    CHAR_TO_TOKEN = {
      '(' => :lparen,
      ')' => :rparen,
      '[' => :lbracket,
      ']' => :rbracket,
      '{' => :left_brace,
      '}' => :right_brace,
      ',' => :comma,
      '.' => :dot,
      ':' => :colon,
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '%' => :modulo,
      '&' => :and,
      '|' => :or,
      '=>' => :arrow
    }.freeze

    FUNCTION_SUGAR = {
      'select' => '__select__'
    }

    # Keywords mapping
    KEYWORDS = {
      'schema' => :schema,
      'input' => :input,
      'value' => :value,
      'trait' => :trait,
      'do' => :do,
      'end' => :end,
      'on' => :on,
      'base' => :base,
      'fn' => :fn,
      'true' => :boolean,
      'false' => :boolean,
      'integer' => :integer_type,
      'float' => :float_type,
      'string' => :string_type,
      'boolean' => :boolean_type,
      'any' => :any_type,
      'array' => :array_type,
      'hash' => :hash_type,
      'element' => :element_type
    }.freeze

    # Opener to closer mappings for error recovery
    OPENER_FOR_CLOSER = {
      rparen: :lparen,
      rbracket: :lbracket
    }.freeze
  end
end
