$:.push File.expand_path("../lib", __FILE__)


Gem::Specification.new do |s|
  s.name = "rego-data-grid".freeze
  s.version = "0.0.28"
  s.authors = ["Alex Tkachev".freeze]
  s.email = "tkachev.alex@gmail.com".freeze
  s.homepage = "http://github.com/alextk/rego-data-grid".freeze
  s.summary = "Ajax data grid with pagination".freeze
  s.description = "Ajax data grid with pagination".freeze
  s.licenses = ["MIT".freeze]
  s.metadata    = {'default_gem_server' => "https://gems.iplan.co.il", 'allowed_push_host' => 'https://gems.iplan.co.il'}

  s.files = Dir["{app,config,lib,public}/**/*"] +  [
    ".document",
    ".rspec",
    "Gemfile",
    "LICENSE.txt",
    "README",
    "README.rdoc",
    "VERSION",
  ]
  s.test_files = Dir["spec/**/*"]
  s.require_paths = ["lib".freeze]

  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README",
    "README.rdoc"
  ]

  s.add_dependency "logging", ">= 1.6"
  s.add_dependency "will_paginate", ">= 3.0.0"
  s.add_dependency "activesupport", ">= 3.0.9"

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'database_cleaner'


end

