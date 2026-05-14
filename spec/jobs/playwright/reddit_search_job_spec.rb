require "rails_helper"

RSpec.describe Playwright::RedditSearchJob, type: :job do
  let(:query)   { "vw polo" }
  let(:service) { instance_double(Playwright::Reddit) }
  let(:results) { [{ title: "Best VW Polo mods", link: "https://old.reddit.com/r/cars/comments/aaa/" }] }

  before do
    allow(Playwright::Reddit).to receive(:new).and_return(service)
    allow(service).to receive(:search).with(query).and_return(results)
  end

  it "calls Playwright::Reddit#search with the given query" do
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

  it "broadcasts the skeleton placeholder to the :search stream targeting reddit-results" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
      :search,
      target: "reddit-results",
      html: described_class::SKELETON_HTML,
    )

    described_class.perform_now(query)
  end
end
