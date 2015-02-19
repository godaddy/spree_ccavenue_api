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
  s.add_dependency 'spree_core', '~> 2.2'

  s.add_development_dependency 'capybara'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl', '4.4'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails',  '2.1.3'
  s.add_development_dependency 'sass-rails', '4.0.2'
  s.add_development_dependency 'selenium-webdriver'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'shoulda-matchers'
end
