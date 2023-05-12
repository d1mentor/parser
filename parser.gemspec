# frozen_string_literal: true

require_relative "lib/parser/version"

Gem::Specification.new do |spec|
  spec.name = "parsergem"
  spec.version = Parser::VERSION
  spec.authors = ["Дмитрий Герасименко"]
  spec.email = ["gerasimenkot92@gmail.com"]

  spec.summary = "Ruby gem for clone site."
  spec.description = "Ruby gem for clone site."
  spec.homepage = "https://github.com/d1mentor/parser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  #spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  #spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.add_dependency 'thor'
  spec.add_dependency 'nokogiri'
  spec.add_dependency "activesupport", ">= 5.0.0"
  spec.add_dependency "rack", ">= 1.4.0"
  spec.add_dependency "ruby-progressbar"
  spec.add_dependency "aws-sdk-translate"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
