class FaviconWebService < Struct.new(:host, :opts)
  attr_accessor :last_url, :favicon_url

  def fetch
    if opts[:naive]
      self.favicon_url = naive_favicon_url
    else
      get_favicon_from_url || get_favicon_from_html
    end
  end

  def get_favicon_from_url
    resp = HTTParty.get(naive_favicon_url)
    return nil unless resp.code == 200

    self.last_url = URI.join(resp.request.last_uri, "/")

    case resp.response.content_type
    when "image/x-icon", "image/vnd.microsoft.icon", "image/gif", "image/png", "image/svg+xml", "text/plain"
      self.favicon_url = resp.request.last_uri
    when "text/html"
      self.favicon_url = find_favicon_uri(resp)
    else
      self.favicon_url = nil
    end
  end

  def get_favicon_from_html
    resp = HTTParty.get(URI.parse(normalized_host_url))

    return nil unless resp.code == 200

    self.last_url = resp.request.last_uri
    self.favicon_url = find_favicon_uri(resp)
  end

  def find_favicon_uri(resp)
    parsed_body = Nokogiri::HTML(resp.body)
    last_uri = resp.request.last_uri

    icons = parsed_body.xpath('//link[@rel="shortcut icon" or @rel="SHORTCUT ICON" or @rel="icon" or @rel="ICON"]')

    if icon = icons.find { |icon| icon["href"] }
      if favicon_uri = URI(icon["href"])
        case favicon_uri
        when URI::HTTP, URI::HTTPS
          favicon_uri
        when URI::Generic
          if favicon_uri.to_s.include?(last_uri.host)
            favicon_uri.scheme = last_uri.scheme
            favicon_uri
          else
            last_uri + favicon_uri
          end
        else
          return nil
        end
      end
    end
  end

  def normalized_host_url
    "http://#{ host }"
  end

  def naive_favicon_url
    URI.parse(normalized_host_url) + "favicon.ico"
  end
end
