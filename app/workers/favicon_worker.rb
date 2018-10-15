class FaviconWorker
  include Sidekiq::Worker

  def perform(url, opts={})
    Site.new(input_url: url, opts: opts.symbolize_keys).tap do |site|
      begin
        site.get_favicon_url
        site.save!
      rescue => e
        Rails.logger.error "unable to fetch favicon for #{ url }: #{ e.class } - #{ e.message }"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
