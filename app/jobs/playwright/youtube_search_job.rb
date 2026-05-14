class Playwright::YoutubeSearchJob < ApplicationJob
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
      target: "youtube-thinking",
      html: SKELETON_HTML,
    )

    results = Playwright::Youtube.new.search(query)
    Rails.logger.info("[Playwright::YoutubeSearchJob] query=#{query.inspect} count=#{results.size}")
    
    Turbo::StreamsChannel.broadcast_update_to(
      :search,
      target: "youtube-thinking",
      html: "",
    )
  end
end
