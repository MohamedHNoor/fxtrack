require "rails_helper"

RSpec.describe User do
  let(:password) { "correct horse battery" }

  it "normalizes the email address" do
    expect(described_class.create!(email_address: "  Owner@Example.COM ", password: password).email_address).to eq("owner@example.com")
  end

  it "requires a 12 to 72 character password" do
    expect(described_class.new(email_address: "owner@example.com", password: "short")).not_to be_valid
    expect(described_class.new(email_address: "owner@example.com", password: "x" * 73)).not_to be_valid
  end

  it "allows only one owner" do
    described_class.create!(email_address: "owner@example.com", password: password)
    second = described_class.new(email_address: "other@example.com", password: password)
    expect(second).not_to be_valid
    expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
