class SearchController < ApplicationController
  def show
  end

  def create
    @query = params[:q].to_s

    if @query.blank?
      respond_to do |format|
        format.html # render the page as-is
        format.turbo_stream { head :no_content } # do nothing
      end
      return
    end

    AnswerJob.perform_later(@query)

    head :no_content

    # respond_to do |format|
    #   format.html # render show.html.erb
    #   format.turbo_stream # render show.turbo_stream.erb (replaces results with "loading ...")
    # end
  end
end
