ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort "RSpec must run in the test environment" unless Rails.env.test?
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
