class Site < ApplicationRecord

  validates :host, presence: true

  def self.batch_import(file_path, opts={})
    cnt = 0
    
    CSV.foreach(file_path) do |row|
      next unless row[1]
      
      if opts[:async]
        FaviconWorker.perform_async(row[1], opts)
      else
        self.new(host: row[1]).tap do |site|
          begin
            site.fetch_favicon_url(opts)
            site.save
          rescue => e
            Rails.logger.error "unable to fetch favicon for #{ row[1] }: #{ e.class } - #{ e.message }"
            Rails.logger.error e.backtrace.join("\n")
          end
        end
      end

      cnt += 1
      GC.start if (cnt % 10_000) == 0

      break if opts[:limit] && cnt >= opts[:limit]
    end
  end

  def self.find_by_input_url(input_url, opts={})
    if site = Site.where(host: normalize_host(input_url)).first
      if opts[:refresh]
        site.fetch_favicon_url(opts)
        site.save
      end
    else
      site = self.new(host: input_url).tap do |site|
        site.fetch_favicon_url(opts)
        site.save
      end
    end
    site
  end

  def host=(val)
    val ? super(normalize_host(val)) : val
  end

  def fetch_favicon_url(opts={})
    service = FaviconWebService.new(host, opts)

    service.fetch.tap do
      self.favicon_url = service.favicon_url
      self.last_url = service.last_url
    end
  end

  def self.normalize_host(url)
    uri = URI.parse(url)
    host =
      case uri
      when URI::HTTP
        uri.host
      when URI::Generic
        url
      end

    host.gsub("www.", "")
  end

  def normalize_host(url)
    self.class.normalize_host(url)
  end
end
