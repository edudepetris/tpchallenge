class AnswerJob < ApplicationJob
  queue_as :default

  def perform(query)
    Playwright::YoutubeSearchJob.perform_later(query)
    Playwright::RedditSearchJob.perform_later(query)
    Playwright::HackerNewsSearchJob.perform_later(query)
  end
end
