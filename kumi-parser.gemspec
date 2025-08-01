# frozen_string_literal: true

require_relative 'lib/kumi/parser/version'

Gem::Specification.new do |spec|
  spec.name = 'kumi-parser'
  spec.version = Kumi::Parser::VERSION
  spec.authors = ['Kumi Team']
  spec.email = ['dev@kumi.ai']

  spec.summary = 'Text parser for Kumi'
  spec.description = 'Allows Kumi schemas to be written as plain text with syntax validation and editor integration.'
  spec.homepage = 'https://github.com/amuta/kumi-parser'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/amuta/kumi-parser'
  spec.metadata['changelog_uri'] = 'https://github.com/amuta/kumi-parser/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'kumi', '~> 0.0.7'
  spec.add_dependency 'parslet', '~> 2.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
