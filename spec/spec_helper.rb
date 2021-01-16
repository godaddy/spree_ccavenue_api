# frozen_string_literal: true

if ENV["COVERAGE"]
  require_relative File.join(@spec_helper_dir, 'rcov_exclude_list.rb')
  exlist = Dir.glob(@exclude_list)
  require 'simplecov'
  require 'simplecov-rcov'
  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.start('rails') { add_filter(exlist) }
end

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../dummy/config/environment.rb',  __FILE__)

require 'rspec/rails'
require 'ffaker'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require f }

# Requires factories defined in spree_core
require 'spree/testing_support/factories'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/authorization_helpers'
require 'spree/testing_support/url_helpers'

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.mock_with :rspec
  config.use_transactional_fixtures = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Spree::TestingSupport::UrlHelpers
  config.include Devise::Test::ControllerHelpers, type: :controller
end
