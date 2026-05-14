class SearchController < ApplicationController
  def show
  end

  def create
    puts params[:query]
  end
end
