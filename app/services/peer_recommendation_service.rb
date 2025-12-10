class PeerRecommendationService
  def initialize(user)
    @user = user
  end

  # Get recommended peers based on mutual connections and social networks
  def recommendations(limit: 20)
    # Get users already connected (peers, pending requests, following)
    excluded_ids = excluded_user_ids

    # Start with mutual connections (friends of friends)
    recommendations = find_mutual_connections(excluded_ids, limit)

    # If we have social network connections, add those
    if recommendations.count < limit
      social_recommendations = find_from_social_networks(excluded_ids, limit - recommendations.count)
      recommendations = merge_recommendations(recommendations, social_recommendations)
    end

    # If still not enough, add users with similar activity/interests
    if recommendations.count < limit
      activity_recommendations = find_similar_users(excluded_ids, limit - recommendations.count)
      recommendations = merge_recommendations(recommendations, activity_recommendations)
    end

    # Sort by relevance score and return
    recommendations.sort_by { |r| -r[:score] }.first(limit)
  end

  private

  # Find peers based on mutual connections (friends of friends)
  def find_mutual_connections(excluded_ids, limit)
    # Get all peers of current user
    user_peer_ids = Peer.where(user_id: @user.id, status: 'accepted')
                       .pluck(:peer_id) +
                    Peer.where(peer_id: @user.id, status: 'accepted')
                       .pluck(:user_id)

    return [] if user_peer_ids.empty?

    # Find users who are peers of the current user's peers
    # This is the "friends of friends" logic
    mutual_connections = Peer.where(user_id: user_peer_ids, status: 'accepted')
                            .where.not(peer_id: excluded_ids + [@user.id])
                            .group(:peer_id)
                            .count

    # Also check reverse direction (where user's peers are the peer_id)
    reverse_mutual = Peer.where(peer_id: user_peer_ids, status: 'accepted')
                        .where.not(user_id: excluded_ids + [@user.id])
                        .group(:user_id)
                        .count

    # Merge and count mutual connections
    all_mutual = (mutual_connections.keys + reverse_mutual.keys).uniq
    mutual_scores = {}

    all_mutual.each do |user_id|
      score = (mutual_connections[user_id] || 0) + (reverse_mutual[user_id] || 0)
      mutual_scores[user_id] = score
    end

    # Get user objects and build recommendations
    user_ids = mutual_scores.sort_by { |_, score| -score }.first(limit).map(&:first)
    users = User.where(id: user_ids).index_by(&:id)

    user_ids.map do |user_id|
      user = users[user_id]
      next unless user

      {
        user: user,
        score: mutual_scores[user_id] * 10, # Weight mutual connections highly
        reason: "#{mutual_scores[user_id]} mutual connection#{mutual_scores[user_id] > 1 ? 's' : ''}",
        source: 'mutual_connections'
      }
    end.compact
  end

  # Find peers from social networks (Facebook, Google, Twitter)
  def find_from_social_networks(excluded_ids, limit)
    recommendations = []

    # Try Facebook if available
    if @user.provider == 'facebook' && @user.oauth_token.present?
      fb_recommendations = find_from_facebook(excluded_ids, limit)
      recommendations.concat(fb_recommendations)
    end

    # Try Google if available
    if @user.provider == 'google_oauth2' && @user.oauth_token.present?
      google_recommendations = find_from_google(excluded_ids, limit - recommendations.count)
      recommendations.concat(google_recommendations)
    end

    # Try Twitter/X if available
    if @user.provider == 'twitter' && @user.oauth_token.present? && @user.oauth_token_secret.present?
      twitter_recommendations = find_from_twitter(excluded_ids, limit - recommendations.count)
      recommendations.concat(twitter_recommendations)
    end

    recommendations.first(limit)
  end

  def find_from_facebook(excluded_ids, limit)
    return [] unless @user.oauth_token.present?

    begin
      require 'net/http'
      require 'json'

      # Get user's Facebook friends
      uri = URI("https://graph.facebook.com/v18.0/me/friends")
      params = { access_token: @user.oauth_token }
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        return []
      end

      data = JSON.parse(response.body)
      friend_uids = (data['data'] || []).map { |f| f['id'] }

      return [] if friend_uids.empty?

      # Find users in our system who are Facebook friends
      users = User.where(provider: 'facebook', uid: friend_uids)
                 .where.not(id: excluded_ids + [@user.id])
                 .limit(limit)

      users.map do |user|
        {
          user: user,
          score: 5, # Medium weight for social connections
          reason: 'Connected on Facebook',
          source: 'facebook'
        }
      end
    rescue => e
      []
    end
  end

  def find_from_google(excluded_ids, limit)
    return [] unless @user.oauth_token.present?

    begin
      require 'net/http'
      require 'json'
      require 'uri'

      # Get user's Google contacts
      uri = URI('https://people.googleapis.com/v1/people/me/connections')
      params = {
        'personFields' => 'names,emailAddresses',
        'pageSize' => limit * 2 # Get more to account for filtering
      }
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Authorization'] = "Bearer #{@user.oauth_token}"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        return []
      end

      data = JSON.parse(response.body)
      connections = data['connections'] || []

      # Extract emails from connections
      contact_emails = []
      connections.each do |connection|
        emails = connection['emailAddresses'] || []
        emails.each { |e| contact_emails << e['value'].downcase.strip if e['value'].present? }
      end

      return [] if contact_emails.empty?

      # Find users in our system who match these emails
      users = User.where(email: contact_emails)
                 .where.not(id: excluded_ids + [@user.id])
                 .limit(limit)

      users.map do |user|
        {
          user: user,
          score: 5, # Medium weight for social connections
          reason: 'In your Google contacts',
          source: 'google'
        }
      end
    rescue => e
      []
    end
  end

  def find_from_twitter(excluded_ids, limit)
    return [] unless @user.oauth_token.present? && @user.oauth_token_secret.present?

    begin
      require 'oauth'
      require 'net/http'
      require 'json'
      require 'uri'

      # Twitter API v2 endpoint for getting following list
      base_url = 'https://api.twitter.com/2/users/me/following'
      params = {
        'max_results' => [limit, 100].min.to_s, # Twitter API max is 100
        'user.fields' => 'username'
      }

      # Create OAuth consumer
      consumer = OAuth::Consumer.new(
        ENV['TWITTER_API_KEY'],
        ENV['TWITTER_API_SECRET'],
        { site: 'https://api.twitter.com' }
      )

      # Create access token
      access_token = OAuth::Token.new(
        @user.oauth_token,
        @user.oauth_token_secret
      )

      # Build request
      uri = URI(base_url)
      uri.query = URI.encode_www_form(params)

      # Create and sign request
      request = Net::HTTP::Get.new(uri.request_uri)
      consumer.sign!(request, access_token)

      # Make request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        return []
      end

      data = JSON.parse(response.body)
      following_data = data['data'] || []

      return [] if following_data.empty?

      # Extract Twitter UIDs (Twitter API returns IDs, not usernames for matching)
      twitter_uids = following_data.map { |f| f['id'] }.compact

      return [] if twitter_uids.empty?

      # Find users in our system who match Twitter UIDs
      users = User.where(provider: 'twitter', uid: twitter_uids)
                 .where.not(id: excluded_ids + [@user.id])
                 .limit(limit)

      users.map do |user|
        {
          user: user,
          score: 5, # Medium weight for social connections
          reason: 'Following on X (Twitter)',
          source: 'twitter'
        }
      end
    rescue => e
      []
    end
  end

  # Find users with similar activity (claims, theories, etc.)
  def find_similar_users(excluded_ids, limit)
    # This is a placeholder for future recommendation logic
    # Could be based on:
    # - Similar claims/theories
    # - Similar naming preferences
    # - Activity patterns
    # - Geographic location (if available)

    # For now, return random users as fallback
    User.where.not(id: excluded_ids + [@user.id])
        .order('RANDOM()')
        .limit(limit)
        .map do |user|
          {
            user: user,
            score: 1, # Low weight for random suggestions
            reason: 'Suggested for you',
            source: 'activity'
          }
        end
  end

  # Merge recommendations, avoiding duplicates
  def merge_recommendations(existing, new_ones)
    existing_user_ids = existing.map { |r| r[:user].id }
    new_ones.each do |recommendation|
      unless existing_user_ids.include?(recommendation[:user].id)
        existing << recommendation
        existing_user_ids << recommendation[:user].id
      end
    end
    existing
  end

  # Get list of user IDs to exclude from recommendations
  def excluded_user_ids
    # Exclude users who are already peers
    peer_ids = Peer.where(user_id: @user.id, status: 'accepted').pluck(:peer_id) +
               Peer.where(peer_id: @user.id, status: 'accepted').pluck(:user_id)

    # Exclude users with pending requests (either direction)
    pending_ids = Peer.where(user_id: @user.id).pluck(:peer_id) +
                  Peer.where(peer_id: @user.id).pluck(:user_id)

    # Exclude users being followed
    following_ids = @user.following.pluck(:id)

    (peer_ids + pending_ids + following_ids).uniq
  end
end
