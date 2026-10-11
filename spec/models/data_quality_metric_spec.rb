require "rails_helper"

RSpec.describe DataQualityMetric do
  it "rejects negative counts and missing request evidence" do
    metric = described_class.new(evaluated_at: Time.current, status: "valid", closed_count: -1,
      incomplete_count: 0, duplicate_count: 0, gap_count: 0)
    expect(metric).not_to be_valid
    expect(metric.errors.attribute_names).to include(:closed_count, :provider_request)
  end
end
