require "rails_helper"

RSpec.describe Playwright::Reddit do
  subject(:service) { described_class.new }

  describe "#search" do
    let(:query) { "vw polo" }
    let(:playwright)   { double("Playwright") }
    let(:browser_type) { double("BrowserType") }
    let(:browser)      { double("Browser") }
    let(:context)      { double("BrowserContext") }
    let(:page)         { double("Page") }

    let(:anchor_one) do
      double("ElementHandle").tap do |a|
        allow(a).to receive(:text_content).and_return("Best VW Polo mods")
        allow(a).to receive(:get_attribute).with("href").and_return("/r/cars/comments/aaa/best_vw_polo_mods/")
      end
    end

    let(:anchor_two) do
      double("ElementHandle").tap do |a|
        allow(a).to receive(:text_content).and_return("VW Polo GTI review thread")
        allow(a).to receive(:get_attribute).with("href").and_return("https://www.reddit.com/r/cars/comments/bbb/")
      end
    end

    before do
      allow(::Playwright).to receive(:create).and_yield(playwright)
      allow(playwright).to receive(:chromium).and_return(browser_type)
      allow(browser_type).to receive(:launch).and_yield(browser)
      allow(browser).to receive(:new_context).and_return(context)
      allow(context).to receive(:new_page).and_return(page)
      allow(page).to receive(:goto)
      allow(page).to receive(:wait_for_selector)
      allow(page).to receive(:query_selector_all).with(described_class::RESULT_SELECTOR)
                                                 .and_return([anchor_one, anchor_two])

      allow_any_instance_of(Playwright::Result).to receive(:broadcast)
    end

    it "navigates to the Reddit search URL with the encoded query" do
      expected_url = "#{described_class::REDDIT_URL}#{described_class::SEARCH_PATH}?q=vw+polo"
      expect(page).to receive(:goto).with(expected_url, hash_including(waitUntil: "domcontentloaded"))

      service.search(query)
    end

    it "sets a desktop user agent on the browser context" do
      expect(browser).to receive(:new_context)
        .with(hash_including(userAgent: described_class::USER_AGENT))
        .and_return(context)

      service.search(query)
    end

    it "waits for post-title anchors before reading them" do
      expect(page).to receive(:wait_for_selector).with(described_class::RESULT_SELECTOR, any_args)

      service.search(query)
    end

    it "returns an array of Playwright::Result objects with source=reddit" do
      results = service.search(query)

      expect(results.map(&:class).uniq).to eq([Playwright::Result])
      expect(results.map { |r| [r.title, r.link, r.source] }).to eq([
        ["Best VW Polo mods",         "https://www.reddit.com/r/cars/comments/aaa/best_vw_polo_mods/", "reddit"],
        ["VW Polo GTI review thread", "https://www.reddit.com/r/cars/comments/bbb/",                   "reddit"],
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
      expect(results.first.title).to eq("Best VW Polo mods")
    end

    it "caps the limit at MAX_LIMIT (10) even when a larger value is requested" do
      many_anchors = Array.new(25) do |i|
        double("ElementHandle").tap do |a|
          allow(a).to receive(:text_content).and_return("Post #{i}")
          allow(a).to receive(:get_attribute).with("href").and_return("/r/cars/comments/#{i}/")
        end
      end
      allow(page).to receive(:query_selector_all).with(described_class::RESULT_SELECTOR).and_return(many_anchors)

      results = service.search(query, limit: 50)

      expect(results.size).to eq(described_class::MAX_LIMIT)
      expect(results.size).to eq(10)
    end
  end
end
