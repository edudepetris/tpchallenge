class Playwright::RedditSearchJob < ApplicationJob
  queue_as :default

  SKELETON_HTML = <<~HTML.html_safe.freeze
    <ul class="panel__list">
      <li class="panel__skeleton"></li>
      <li class="panel__skeleton"></li>
      <li class="panel__skeleton"></li>
    </ul>
  HTML

  def perform(query)
    Turbo::StreamsChannel.broadcast_update_to(
      :search,
      target: "reddit-results",
      html: SKELETON_HTML,
    )

    results = Playwright::Reddit.new.search(query)
    Rails.logger.info("[Playwright::RedditSearchJob] query=#{query.inspect} count=#{results.size}")
    results
  end
end
