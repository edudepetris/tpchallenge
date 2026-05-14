require "playwright"

QUERY = "vw polo"
PLAYWRIGHT_CLI = ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "npx playwright")

results = []

Playwright.create(playwright_cli_executable_path: PLAYWRIGHT_CLI) do |playwright|
  playwright.chromium.launch(headless: true) do |browser|
    context = browser.new_context(locale: "en-US")
    page = context.new_page
    page.goto("https://www.youtube.com/results?search_query=#{URI.encode_www_form_component(QUERY)}")

    # Dismiss consent dialog if present (EU/region dependent).
    begin
      page.locator('button:has-text("Accept all")').first.click(timeout: 3000)
    rescue Playwright::TimeoutError
      # No consent dialog — continue.
    end

    page.locator("ytd-video-renderer a#video-title").first.wait_for(timeout: 15000)

    anchors = page.locator("ytd-video-renderer a#video-title").element_handles
    anchors.first(10).each do |a|
      title = (a.get_attribute("title") || a.text_content).to_s.strip
      href = a.get_attribute("href").to_s
      next if title.empty? || href.empty?

      link = href.start_with?("http") ? href : "https://www.youtube.com#{href}"
      results << { title: title, link: link }
    end
  end
end

require "json"
puts JSON.pretty_generate(results)
