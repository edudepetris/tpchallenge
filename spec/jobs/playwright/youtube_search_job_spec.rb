require "rails_helper"

RSpec.describe Playwright::YoutubeSearchJob, type: :job do
  let(:query)   { "vw polo" }
  let(:service) { instance_double(Playwright::Youtube) }
  let(:results) { [{ title: "VW Polo Review", link: "https://www.youtube.com/watch?v=aaa" }] }

  before do
    allow(Playwright::Youtube).to receive(:new).and_return(service)
    allow(service).to receive(:search).with(query).and_return(results)
  end

  it "calls Playwright::Youtube#search with the given query" do
    described_class.perform_now(query)

    expect(service).to have_received(:search).with(query)
  end

  it "returns the search results" do
    expect(described_class.perform_now(query)).to eq(results)
  end

  it "is enqueued on the default queue" do
    expect {
      described_class.perform_later(query)
    }.to have_enqueued_job(described_class).with(query).on_queue("default")
  end

  it "broadcasts the skeleton placeholder to the :search stream targeting youtube-results" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
      :search,
      target: "youtube-results",
      html: described_class::SKELETON_HTML,
    )

    described_class.perform_now(query)
  end
end
