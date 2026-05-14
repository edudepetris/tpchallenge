require "playwright"

class Playwright::HackerNews
  SEARCH_URL = "https://hn.algolia.com/".freeze
  RESULT_SELECTOR = "a.Story_link".freeze
  SOURCE = "hacker_news".freeze
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
        page.goto("#{SEARCH_URL}?q=#{URI.encode_www_form_component(query)}")

        page.locator(RESULT_SELECTOR).first.wait_for(timeout: 15_000)

        page.locator(RESULT_SELECTOR).element_handles.first(limit).each do |a|
          title = a.text_content.to_s.strip
          href = a.get_attribute("href").to_s
          next if title.empty? || href.empty?

          link = href.start_with?("http") ? href : "https://hn.algolia.com#{href}"
          result = ::Playwright::Result.new(title: title, link: link, source: SOURCE)
          result.broadcast
          results << result
        end
      end
    end

    results
  end
end
