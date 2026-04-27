# config/initializers/chargebee.rb
site = ENV["CHARGEBEE_SITE"]
api_key = ENV["CHARGEBEE_API_KEY"]

if site.present? && api_key.present?
  connect_timeout = ENV.fetch("CHARGEBEE_CONNECT_TIMEOUT", "15").to_i
  read_timeout = ENV.fetch("CHARGEBEE_READ_TIMEOUT", "90").to_i

  begin
    ChargeBee.configure(
      site: site,
      api_key: api_key,
      connect_timeout: connect_timeout,
      read_timeout: read_timeout
    )
  rescue ArgumentError
    ChargeBee.configure(site: site, api_key: api_key)
  end

  ChargeBee.update_connect_timeout_secs(connect_timeout) if ChargeBee.respond_to?(:update_connect_timeout_secs)
  ChargeBee.update_read_timeout_secs(read_timeout) if ChargeBee.respond_to?(:update_read_timeout_secs)
end
