class FaviconsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    if strong_params[:site] && strong_params[:site][:input_url]
      @site = Site.find_by_input_url(strong_params[:site][:input_url], refresh: false)
    else
      @site = Site.new
    end
  end

  private

  def strong_params
    params.permit(
      site: :input_url
    )
  end
end
