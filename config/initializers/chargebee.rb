# config/initializers/chargebee.rb
ChargeBee.configure(site: ENV['CHARGEBEE_SITE'], api_key: ENV['CHARGEBEE_API_KEY'])
