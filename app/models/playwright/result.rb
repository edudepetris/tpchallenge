require "playwright"

class Playwright::Result
  include ActiveModel::Model
  include ActiveModel::Attributes

  STREAM = :search

  attribute :title,  :string
  attribute :link,   :string
  attribute :source, :string

  validates :title, :link, :source, presence: true

  def broadcast
    Turbo::StreamsChannel.broadcast_append_to(
      STREAM,
      target: "#{source}-results",
      partial: "playwright/results/result",
      locals: { result: self },
    )
  end
end
