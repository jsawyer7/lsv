class PeerFinderService
  def initialize(user)
    @user = user
  end

  # Find peers from social networks
  def find_from_social_networks(provider)
    case provider.to_s
    when 'facebook'
      find_from_facebook
    when 'google_oauth2', 'google'
      find_from_google
    when 'twitter'
      find_from_twitter
    else
      { error: "Unsupported provider: #{provider}" }
    end
  rescue => e
    Rails.logger.error "Error finding peers from #{provider}: #{e.message}\n#{e.backtrace.join("\n")}"
    { error: e.message }
  end

  # Find peers from phone contacts
  def find_from_phone_contacts(contacts_data)
    return { error: 'No contacts provided' } if contacts_data.blank?

    found_users = []
    contacts_data.each do |contact|
      # Try to find users by email or phone
      email = contact['email'] || contact[:email]
      phone = contact['phone'] || contact[:phone]
      name = contact['name'] || contact[:name]

      user = nil
      if email.present?
        user = User.find_by(email: email.downcase.strip)
      end

      if user.nil? && phone.present?
        # Normalize phone number (remove spaces, dashes, etc.)
        normalized_phone = phone.gsub(/[\s\-\(\)]/, '')
        user = User.where("REPLACE(REPLACE(REPLACE(REPLACE(phone, ' ', ''), '-', ''), '(', ''), ')', '') = ?", normalized_phone).first
      end

      if user && user != @user && !already_peer?(user)
        found_users << {
          user: user,
          match_type: email.present? ? 'email' : 'phone',
          contact_name: name
        }
      end
    end

    { users: found_users, count: found_users.count }
  end

  private

  def find_from_facebook
    return { error: 'Facebook OAuth token not available' } unless @user.oauth_token.present?

    # Facebook Graph API requires access token
    # Note: Facebook API v2.0+ requires specific permissions for friends list
    # This is a simplified version - you may need to request additional permissions
    require 'net/http'
    require 'json'

    uri = URI("https://graph.facebook.com/v18.0/me/friends")
    params = { access_token: @user.oauth_token }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    return { error: 'Failed to fetch Facebook friends' } unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    friends = data['data'] || []

    found_users = []
    friends.each do |friend|
      # Facebook friends API only returns basic info (id, name)
      # We need to match by Facebook UID
      user = User.find_by(provider: 'facebook', uid: friend['id'])
      if user && user != @user && !already_peer?(user)
        found_users << {
          user: user,
          match_type: 'facebook_uid',
          social_name: friend['name']
        }
      end
    end

    { users: found_users, count: found_users.count }
  end

  def find_from_google
    return { error: 'Google OAuth token not available' } unless @user.oauth_token.present?

    require 'net/http'
    require 'json'
    require 'uri'

    # Google People API to get contacts
    # Note: Requires 'contacts.readonly' scope
    uri = URI('https://people.googleapis.com/v1/people/me/connections')
    params = {
      'personFields' => 'names,emailAddresses,phoneNumbers',
      'pageSize' => 100
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@user.oauth_token}"

    response = http.request(request)
    return { error: 'Failed to fetch Google contacts' } unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    connections = data['connections'] || []

    found_users = []
    connections.each do |connection|
      emails = connection['emailAddresses'] || []
      phones = connection['phoneNumbers'] || []
      names = connection['names'] || []
      name = names.first&.dig('displayName') || names.first&.dig('givenName')

      # Try to find user by email
      emails.each do |email_obj|
        email = email_obj['value']
        next unless email.present?

        user = User.find_by(email: email.downcase.strip)
        if user && user != @user && !already_peer?(user)
          found_users << {
            user: user,
            match_type: 'email',
            contact_name: name
          }
          break # Found user, no need to check other emails
        end
      end

      # If not found by email, try phone
      if found_users.none? { |f| f[:user].email == emails.first&.dig('value') }
        phones.each do |phone_obj|
          phone = phone_obj['value']
          next unless phone.present?

          normalized_phone = phone.gsub(/[\s\-\(\)]/, '')
          user = User.where("REPLACE(REPLACE(REPLACE(REPLACE(phone, ' ', ''), '-', ''), '(', ''), ')', '') = ?", normalized_phone).first
          if user && user != @user && !already_peer?(user)
            found_users << {
              user: user,
              match_type: 'phone',
              contact_name: name
            }
            break
          end
        end
      end
    end

    { users: found_users, count: found_users.count }
  end

  def find_from_twitter
    return { error: 'Twitter OAuth tokens not available' } unless @user.oauth_token.present? && @user.oauth_token_secret.present?

    # Twitter API v2 requires OAuth 1.0a signing
    # This is a simplified version - you'll need the oauth gem for proper signing
    require 'net/http'
    require 'json'
    require 'uri'
    require 'base64'
    require 'openssl'

    # Twitter API v2 - Get following list
    # Note: This requires OAuth 1.0a signing which is complex
    # For now, we'll use a simplified approach that may need adjustment

    # Twitter API endpoint for getting following
    uri = URI('https://api.twitter.com/2/users/me/following')
    params = { max_results: 100 }
    uri.query = URI.encode_www_form(params)

    # OAuth 1.0a signing would go here
    # For production, use the 'oauth' gem or similar
    # This is a placeholder that shows the structure

    # For now, return a message that this requires additional setup
    {
      error: 'Twitter API integration requires OAuth 1.0a signing. Please use the oauth gem for full implementation.',
      note: 'Twitter API v2 requires proper OAuth 1.0a request signing which is complex to implement inline.'
    }
  end

  def already_peer?(user)
    Peer.exists?(
      user_id: @user.id,
      peer_id: user.id
    ) || Peer.exists?(
      user_id: user.id,
      peer_id: @user.id
    )
  end
end
