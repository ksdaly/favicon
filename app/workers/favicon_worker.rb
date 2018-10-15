class FaviconWorker
  include Sidekiq::Worker

  def perform(url, opts={})
    Site.new(host: url).tap do |site|
      begin
        site.fetch_favicon_url(opts.symbolize_keys)
        site.save
      rescue => e
        Rails.logger.error "unable to fetch favicon for #{ url }: #{ e.class } - #{ e.message }"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
