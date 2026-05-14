require "rails_helper"

RSpec.describe Playwright::Youtube do
  subject(:service) { described_class.new }

  describe "#search" do
    let(:query) { "vw polo" }
    let(:playwright)   { double("Playwright") }
    let(:browser_type) { double("BrowserType") }
    let(:browser)      { double("Browser") }
    let(:context)      { double("BrowserContext") }
    let(:page)         { double("Page") }
    let(:results_locator) { double("Locator") }
    let(:first_locator)   { double("Locator") }
    let(:consent_locator) { double("Locator") }
    let(:consent_first)   { double("Locator") }

    let(:anchor_one) do
      double("ElementHandle").tap do |a|
        allow(a).to receive(:get_attribute).with("title").and_return("VW Polo Review")
        allow(a).to receive(:get_attribute).with("href").and_return("/watch?v=aaa")
        allow(a).to receive(:text_content).and_return("Result 1")
      end
    end

    let(:anchor_two) do
      double("ElementHandle").tap do |a|
        allow(a).to receive(:get_attribute).with("title").and_return(nil)
        allow(a).to receive(:text_content).and_return("VW Polo GTI")
        allow(a).to receive(:get_attribute).with("href").and_return("https://youtu.be/bbb")
      end
    end

    before do
      allow(::Playwright).to receive(:create).and_yield(playwright)
      allow(playwright).to receive(:chromium).and_return(browser_type)
      allow(browser_type).to receive(:launch).and_yield(browser)
      allow(browser).to receive(:new_context).and_return(context)
      allow(context).to receive(:new_page).and_return(page)
      allow(page).to receive(:goto)

      allow(page).to receive(:locator).with('button:has-text("Accept all")').and_return(consent_locator)
      allow(consent_locator).to receive(:first).and_return(consent_first)
      allow(consent_first).to receive(:click).and_raise(::Playwright::TimeoutError.new(message: "no consent"))

      allow(page).to receive(:locator).with(described_class::RESULT_SELECTOR).and_return(results_locator)
      allow(results_locator).to receive(:first).and_return(first_locator)
      allow(first_locator).to receive(:wait_for)
      allow(results_locator).to receive(:element_handles).and_return([ anchor_one, anchor_two ])

      allow_any_instance_of(Playwright::Result).to receive(:broadcast)
    end

    it "navigates to the YouTube search URL with the encoded query" do
      expected_url = "#{described_class::SEARCH_URL}?search_query=vw+polo"
      expect(page).to receive(:goto).with(expected_url)

      service.search(query)
    end

    it "returns an array of Playwright::Result objects with source=youtube" do
      results = service.search(query)

      expect(results.map(&:class).uniq).to eq([ Playwright::Result ])
      expect(results.map { |r| [ r.title, r.link, r.source ] }).to eq([
        [ "VW Polo Review", "https://www.youtube.com/watch?v=aaa", "youtube" ],
        [ "VW Polo GTI",    "https://youtu.be/bbb",                "youtube" ]
      ])
    end

    it "broadcasts each result immediately after building it" do
      broadcasted = []
      allow_any_instance_of(Playwright::Result).to receive(:broadcast) do |instance|
        broadcasted << instance
      end

      results = service.search(query)

      expect(broadcasted.size).to eq(2)
      expect(broadcasted).to eq(results)
    end

    it "honors the limit argument" do
      results = service.search(query, limit: 1)

      expect(results.size).to eq(1)
      expect(results.first.title).to eq("VW Polo Review")
    end

    it "caps the limit at MAX_LIMIT (10) even when a larger value is requested" do
      many_anchors = Array.new(25) do |i|
        double("ElementHandle").tap do |a|
          allow(a).to receive(:get_attribute).with("title").and_return("Video #{i}")
          allow(a).to receive(:get_attribute).with("href").and_return("/watch?v=#{i}")
          allow(a).to receive(:text_content).and_return("Video #{i}")
        end
      end
      allow(results_locator).to receive(:element_handles).and_return(many_anchors)

      results = service.search(query, limit: 50)

      expect(results.size).to eq(described_class::MAX_LIMIT)
      expect(results.size).to eq(10)
    end
  end
end
