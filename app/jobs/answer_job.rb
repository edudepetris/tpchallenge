class AnswerJob < ApplicationJob
  queue_as :default

  def perform(query)
    Playwright::YoutubeSearchJob.perform_later(query)
  end
end
