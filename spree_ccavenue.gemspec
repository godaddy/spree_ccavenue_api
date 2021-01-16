# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_ccavenue'
  s.version     = '3.1'
  s.summary     = 'CCAvenue payment gateway support for Spree'
  s.description = 'CCAvenue is a payment gateway in India. This gem provides suppport for CCAvenue in Spree Commerce'
  s.required_ruby_version = '>= 1.9.3'

  s.author            = 'BlueZeal'
  s.email             = 'service@ccavenue.com'
  s.homepage          = 'http://ccavenue.com/'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'rest-client'
  s.add_dependency 'spree_core', '~> 3.0.0'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'simplecov-rcov'
  s.add_development_dependency 'yarjuf'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'shoulda-matchers'
end
