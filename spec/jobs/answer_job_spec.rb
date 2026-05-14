require "rails_helper"

RSpec.describe AnswerJob, type: :job do
  let(:query) { "vw polo" }

  it "enqueues a Playwright::YoutubeSearchJob with the query" do
    expect {
      described_class.perform_now(query)
    }.to have_enqueued_job(Playwright::YoutubeSearchJob).with(query).on_queue("default")
  end

  it "is itself enqueued on the default queue" do
    expect {
      described_class.perform_later(query)
    }.to have_enqueued_job(described_class).with(query).on_queue("default")
  end
end
