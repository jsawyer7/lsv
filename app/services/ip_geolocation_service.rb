class IpGeolocationService
  def initialize(ip_address)
    @ip_address = ip_address
  end

  # Get location data from IP address
  def fetch_location
    return nil if @ip_address.blank? || @ip_address == '127.0.0.1' || @ip_address == '::1'

    begin
      require 'net/http'
      require 'json'
      require 'uri'

      # Using ip-api.com (free, no API key required, 45 requests/minute)
      # Alternative: Use MaxMind GeoIP2, ipinfo.io, or other services
      uri = URI("http://ip-api.com/json/#{@ip_address}")
      params = {
        'fields' => 'status,message,country,regionName,city,lat,lon'
      }
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        return nil
      end

      data = JSON.parse(response.body)

      # Check if request was successful
      return nil unless data['status'] == 'success'

      {
        latitude: data['lat']&.to_f,
        longitude: data['lon']&.to_f,
        city: data['city'],
        country: data['country']
      }
    rescue => e
      nil
    end
  end

  # Alternative: Using ipinfo.io (requires API key but more reliable)
  def fetch_location_from_ipinfo(api_key = nil)
    return nil if @ip_address.blank? || @ip_address == '127.0.0.1' || @ip_address == '::1'

    begin
      require 'net/http'
      require 'json'
      require 'uri'

      uri = URI("https://ipinfo.io/#{@ip_address}/json")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Authorization'] = "Bearer #{api_key}" if api_key.present?

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        return nil
      end

      data = JSON.parse(response.body)

      # Parse lat/lon from loc field (format: "lat,lon")
      lat, lon = data['loc']&.split(',')&.map(&:to_f)

      {
        latitude: lat,
        longitude: lon,
        city: data['city'],
        country: data['country']
      }
    rescue => e
      nil
    end
  end
end
