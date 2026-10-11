ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort "RSpec must run in the test environment" unless Rails.env.test?
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Rate limits live in the cache store, so each example starts with a clean count.
  config.before do
    Rails.cache.clear
    CurrencyPair.ensure_seeded!
  end

  config.include ActiveSupport::Testing::TimeHelpers
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
