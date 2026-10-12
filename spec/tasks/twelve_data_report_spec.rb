require "rails_helper"
require "rake"

RSpec.describe "twelve_data:report" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("twelve_data:report")
    Rake::Task["twelve_data:report"].reenable
  end

  it "prints the acceptance gate and recorded retention decision" do
    expect { Rake::Task["twelve_data:report"].invoke }
      .to output(/"gate":"pending","historical_retention":"owner decision recorded 2026-10-11/).to_stdout
  end
end
