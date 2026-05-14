require "rails_helper"

RSpec.describe Playwright::HackerNewsSearchJob, type: :job do
  let(:query)   { "vw polo" }
  let(:service) { instance_double(Playwright::HackerNews) }
  let(:results) { [ { title: "Show HN: VW Polo dashboard hack", link: "https://example.com/polo-hack" } ] }

  before do
    allow(Playwright::HackerNews).to receive(:new).and_return(service)
    allow(service).to receive(:search).with(query).and_return(results)
  end

  it "calls Playwright::HackerNews#search with the given query" do
    described_class.perform_now(query)

    expect(service).to have_received(:search).with(query)
  end

  it "is enqueued on the default queue" do
    expect {
      described_class.perform_later(query)
    }.to have_enqueued_job(described_class).with(query).on_queue("default")
  end

  it "broadcasts the skeleton placeholder to the :search stream targeting hacker_news-thinking" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
      :search,
      target: "hacker_news-thinking",
      html: described_class::SKELETON_HTML,
    ).ordered

    expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
      :search,
      target: "hacker_news-thinking",
      html: "",
    ).ordered

    described_class.perform_now(query)
  end
end
