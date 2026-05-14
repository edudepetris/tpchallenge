require "rails_helper"

RSpec.describe Playwright::YoutubeSearchJob, type: :job do
  let(:query)   { "vw polo" }
  let(:service) { instance_double(Playwright::Youtube) }
  let(:results) { [ { title: "VW Polo Review", link: "https://www.youtube.com/watch?v=aaa" } ] }

  before do
    allow(Playwright::Youtube).to receive(:new).and_return(service)
    allow(service).to receive(:search).with(query).and_return(results)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  it "calls Playwright::Youtube#search with the given query" do
    described_class.perform_now(query)

    expect(service).to have_received(:search).with(query)
  end

  it "is enqueued on the default queue" do
    expect {
      described_class.perform_later(query)
    }.to have_enqueued_job(described_class).with(query).on_queue("default")
  end

  it "broadcasts the skeleton placeholder to the :search stream targeting youtube-thinking" do
    described_class.perform_now(query)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      :search,
      target: "youtube-thinking",
      html: described_class::SKELETON_HTML,
    )
  end

  it "clears the youtube-thinking target once the search completes" do
    described_class.perform_now(query)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to).with(
      :search,
      target: "youtube-thinking",
      html: "",
    )
  end
end
