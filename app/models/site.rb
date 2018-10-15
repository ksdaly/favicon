class Site < ApplicationRecord
  attr_accessor :input_url, :opts

  validates :host, presence: true

  def self.batch_import(file_path, opts={})
    cnt = 0
    
    CSV.foreach(file_path) do |row|
      next unless row[1]
      
      if opts[:async]
        FaviconWorker.perform_async(row[1], opts)
      else
        new(input_url: row[1], opts: opts).tap do |site|
          begin
            site.get_favicon_url
            site.save!
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
    site = Site.where(host: input_url).first
    if site
      site.input_url = input_url
      if opts[:refresh]
        site.get_favicon_url
        site.save
      end
    else
      site = new(input_url: input_url).tap do |site|
        site.get_favicon_url
        site.save!
      end
    end
    site
  end

  def host=(val)
    super(normalize_host(val))
  end

  def opts
    @opts ||= {
      verify: true,
      async: false
    }
  end

  def get_favicon_url
    if opts[:verify]
      get_favicon_from_url || get_favicon_from_html
    else
      self.host = input_url
      self.favicon_url = naive_favicon_url
    end
  end

  private

  def get_favicon_from_url
    resp = HTTParty.get(naive_favicon_url)
    return unless resp.code == 200

    last_uri = resp.request.last_uri
    self.host = last_uri.host
    self.last_url = URI.join(last_uri, '/')

    case resp.response.content_type
    when "image/x-icon", "text/plain"
      self.favicon_url = last_uri
    when "text/html"
      self.favicon_url = find_favicon_uri(resp)
    else
      return nil
    end
  end

  def get_favicon_from_html
    resp = HTTParty.get(URI.parse(last_url || self.class.normalize_input_url(input_url)))

    return unless resp.code == 200

    last_uri = resp.request.last_uri

    self.host = last_uri.host
    self.last_url = last_uri

    self.favicon_url = find_favicon_uri(resp)
  end

  def find_favicon_uri(resp)
    parsed_body = Nokogiri::HTML(resp.body)
    last_uri = resp.request.last_uri

    icons = parsed_body.xpath('//link[@rel="shortcut icon" or @rel="SHORTCUT ICON" or @rel="icon" or @rel="ICON"]')

    if icon = icons.find { |icon| icon['href'] }
      if favicon_uri = URI(icon['href'])
        case favicon_uri
        when URI::Generic
          if favicon_uri.to_s.include?(last_uri.host)
            favicon_uri.scheme = last_uri.scheme
            favicon_uri
          else
            last_uri + favicon_uri
          end
        when URI::HTTP
          favicon_uri
        else
          nil
        end
      end
    end
  end

  def normalize_host(val)
    return unless val
    
    val.gsub('www.', '')
  end

  def self.normalize_input_url(url)
    url =~ URI::regexp(%w(http https)) ? url : "http://#{ url }"
  end

  def naive_favicon_url
    URI.parse(last_url || self.class.normalize_input_url(input_url)) + "favicon.ico"
  end
end
