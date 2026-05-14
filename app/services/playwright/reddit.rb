require "cgi"
require "playwright"

class Playwright::Reddit
  REDDIT_URL = "https://www.reddit.com".freeze
  SEARCH_PATH = "/search/".freeze
  RESULT_SELECTOR = 'a[data-testid="post-title-text"]'.freeze
  SOURCE = "reddit".freeze
  MAX_LIMIT = 10
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
               "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
  PLAYWRIGHT_CLI = ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "npx playwright").freeze

  def search(query, limit: MAX_LIMIT)
    limit = [ limit.to_i, MAX_LIMIT ].min
    limit = MAX_LIMIT if limit <= 0
    results = []

    ::Playwright.create(playwright_cli_executable_path: PLAYWRIGHT_CLI) do |playwright|
      playwright.chromium.launch(headless: true) do |browser|
        context = browser.new_context(locale: "en-US", userAgent: USER_AGENT)
        page = context.new_page
        page.goto("#{REDDIT_URL}#{SEARCH_PATH}?q=#{CGI.escape(query)}", waitUntil: "domcontentloaded")

        page.wait_for_selector(RESULT_SELECTOR, timeout: 30_000)

        results = page.query_selector_all(RESULT_SELECTOR).first(limit).map do |link|
          href = link.get_attribute("href").to_s
          title = link.text_content.to_s.strip

          result = ::Playwright::Result.new(
            title: title,
            link: href.start_with?("http") ? href : "#{REDDIT_URL}#{href}",
            source: SOURCE,
          )
          result.broadcast
          result
        end
      end
    end

    results
  end
end
