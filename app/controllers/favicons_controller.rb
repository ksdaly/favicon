class FaviconsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :require_input_url
  before_action :require_site

  SERVER_ERROR = "Favicon could not be found: server error"
  VALIDATION_ERROR = "Favicon could not be found: invalid URL"

  def index
    if @input_url
      begin
        if valid_input_url
          @site = Site.find_by_input_url_and_fetch_favicon_url(@input_url, refresh: false)
        else
          @error = VALIDATION_ERROR
        end
      rescue => e
        @error = SERVER_ERROR
        Rails.logger.error "unable to fetch favicon for #{ @input_url }: #{ e.class } - #{ e.message }"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end

  private

  def strong_params
    params.permit(
      site: :input_url
    )
  end

  def require_input_url
    @input_url = strong_params[:site] && strong_params[:site][:input_url]
  end

  def require_site
    @site = Site.new
  end

  def valid_input_url
    @input_url && URI.parse(@input_url).host
  end
end
