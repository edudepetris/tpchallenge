require "rails_helper"

RSpec.describe Playwright::Result, type: :model do
  let(:attrs) do
    { title: "VW Polo Review", link: "https://youtu.be/aaa", source: "youtube" }
  end

  subject(:result) { described_class.new(attrs) }

  describe "attributes" do
    it "exposes title, link, and source" do
      expect(result).to have_attributes(
        title: "VW Polo Review",
        link: "https://youtu.be/aaa",
        source: "youtube",
      )
    end
  end

  describe "validations" do
    it { is_expected.to be_valid }

    %i[title link source].each do |attr|
      it "is invalid without #{attr}" do
        result.public_send("#{attr}=", nil)
        expect(result).not_to be_valid
        expect(result.errors[attr]).to include("can't be blank")
      end
    end
  end

  describe "#broadcast" do
    it "appends the result partial to the :search stream targeting <source>-results" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        described_class::STREAM,
        target: "youtube-results",
        partial: "playwright/results/result",
        locals: { result: result },
      )

      result.broadcast
    end
  end
end
