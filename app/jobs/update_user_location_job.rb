class UpdateUserLocationJob < ApplicationJob
  queue_as :default

  def perform(user_id, ip_address)
    user = User.find_by(id: user_id)
    return unless user

    # Skip if location was recently updated
    return if user.latitude.present? && user.longitude.present? &&
              user.updated_at > 7.days.ago

    geolocation_service = IpGeolocationService.new(ip_address)
    location_data = geolocation_service.fetch_location

    return unless location_data && location_data[:latitude].present? && location_data[:longitude].present?

    user.update(
      latitude: location_data[:latitude],
      longitude: location_data[:longitude],
      city: location_data[:city],
      country: location_data[:country]
    )
  end
end
