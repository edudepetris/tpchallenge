require "playwright"

class Playwright::Youtube
  SEARCH_URL = "https://www.youtube.com/results".freeze
  RESULT_SELECTOR = "ytd-video-renderer a#video-title".freeze
  SOURCE = "youtube".freeze
  MAX_LIMIT = 10
  PLAYWRIGHT_CLI = ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "npx playwright").freeze

  def search(query, limit: MAX_LIMIT)
    limit = [limit.to_i, MAX_LIMIT].min
    limit = MAX_LIMIT if limit <= 0
    results = []

    ::Playwright.create(playwright_cli_executable_path: PLAYWRIGHT_CLI) do |playwright|
      playwright.chromium.launch(headless: true) do |browser|
        context = browser.new_context(locale: "en-US")
        page = context.new_page
        page.goto("#{SEARCH_URL}?search_query=#{URI.encode_www_form_component(query)}")

        dismiss_consent(page)

        page.locator(RESULT_SELECTOR).first.wait_for(timeout: 15_000)

        page.locator(RESULT_SELECTOR).element_handles.first(limit).each do |a|
          title = (a.get_attribute("title") || a.text_content).to_s.strip
          href = a.get_attribute("href").to_s
          next if title.empty? || href.empty?

          link = href.start_with?("http") ? href : "https://www.youtube.com#{href}"
          result = ::Playwright::Result.new(title: title, link: link, source: SOURCE)
          result.broadcast
          results << result
        end
      end
    end

    results
  end

  private

  def dismiss_consent(page)
    page.locator('button:has-text("Accept all")').first.click(timeout: 3_000)
  rescue ::Playwright::TimeoutError
    # No consent dialog — continue.
  end
end
