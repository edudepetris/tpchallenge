require "rails_helper"

RSpec.describe Playwright::HackerNews do
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

    let(:anchor_one) do
      double("ElementHandle").tap do |a|
        allow(a).to receive(:text_content).and_return("Show HN: VW Polo dashboard hack")
        allow(a).to receive(:get_attribute).with("href").and_return("https://example.com/polo-hack")
      end
    end

    let(:anchor_two) do
      double("ElementHandle").tap do |a|
        allow(a).to receive(:text_content).and_return("Ask HN: VW Polo OBD tooling?")
        allow(a).to receive(:get_attribute).with("href").and_return("/comments/123")
      end
    end

    before do
      allow(::Playwright).to receive(:create).and_yield(playwright)
      allow(playwright).to receive(:chromium).and_return(browser_type)
      allow(browser_type).to receive(:launch).and_yield(browser)
      allow(browser).to receive(:new_context).and_return(context)
      allow(context).to receive(:new_page).and_return(page)
      allow(page).to receive(:goto)

      allow(page).to receive(:locator).with(described_class::RESULT_SELECTOR).and_return(results_locator)
      allow(results_locator).to receive(:first).and_return(first_locator)
      allow(first_locator).to receive(:wait_for)
      allow(results_locator).to receive(:element_handles).and_return([anchor_one, anchor_two])

      allow_any_instance_of(Playwright::Result).to receive(:broadcast)
    end

    it "navigates to the HN Algolia search URL with the encoded query" do
      expected_url = "#{described_class::SEARCH_URL}?q=vw+polo"
      expect(page).to receive(:goto).with(expected_url)

      service.search(query)
    end

    it "returns an array of Playwright::Result objects with source=hacker_news" do
      results = service.search(query)

      expect(results.map(&:class).uniq).to eq([Playwright::Result])
      expect(results.map { |r| [r.title, r.link, r.source] }).to eq([
        ["Show HN: VW Polo dashboard hack", "https://example.com/polo-hack",       "hacker_news"],
        ["Ask HN: VW Polo OBD tooling?",    "https://hn.algolia.com/comments/123", "hacker_news"],
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
      expect(results.first.title).to eq("Show HN: VW Polo dashboard hack")
    end

    it "caps the limit at MAX_LIMIT (10) even when a larger value is requested" do
      many_anchors = Array.new(25) do |i|
        double("ElementHandle").tap do |a|
          allow(a).to receive(:text_content).and_return("Story #{i}")
          allow(a).to receive(:get_attribute).with("href").and_return("https://example.com/#{i}")
        end
      end
      allow(results_locator).to receive(:element_handles).and_return(many_anchors)

      results = service.search(query, limit: 50)

      expect(results.size).to eq(described_class::MAX_LIMIT)
      expect(results.size).to eq(10)
    end
  end
end
