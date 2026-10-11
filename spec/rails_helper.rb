ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort "RSpec must run in the test environment" unless Rails.env.test?
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Rate limits live in the cache store, so each example starts with a clean count.
  config.before { Rails.cache.clear }

  config.include ActiveSupport::Testing::TimeHelpers
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
