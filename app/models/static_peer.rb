class StaticPeer
  ALL = [
    { full_name: 'Verifaith', avatar_url: nil, followers_count: 214 },
    { full_name: 'Veritalk', avatar_url: nil, followers_count: 189 },
    { full_name: 'VeriCommunity', avatar_url: nil, followers_count: 156 }
  ].freeze

  attr_reader :full_name, :avatar_url, :followers_count

  def initialize(full_name:, avatar_url: nil, followers_count: 0)
    @full_name = full_name
    @avatar_url = avatar_url
    @followers_count = followers_count
  end

  def static?
    true
  end

  def followers
    @followers ||= Struct.new(:count, :to_a).new(followers_count, [])
  end

  def self.take(need)
    return [] if need <= 0
    ALL.first(need).map { |h| new(**h) }
  end
end
