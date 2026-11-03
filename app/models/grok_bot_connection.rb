# An access token that lets a Grok Bot read LSV data through the MCP endpoint
# (POST /mcp, see McpController). Admins create connections in the admin panel,
# choose which data groups (scopes) each may read, and paste the token into the
# Grok Bot custom connector. Only a SHA-256 digest of the token is stored.
class GrokBotConnection < ApplicationRecord
  TOKEN_PREFIX = 'lsv_'.freeze

  SCOPES = {
    'scripture' => 'Scripture texts: sources, books, canons, verses and word-by-word morphology',
    'dictionary' => 'Dictionary entries and name mappings',
    'claims' => 'Claims, evidence, challenges and their reasonings (all users, including unpublished)',
    'translations' => 'Verse translations'
  }.freeze

  belongs_to :created_by, class_name: 'User', optional: true
  has_many :tool_calls, class_name: 'GrokBotToolCall', dependent: :delete_all

  # Set by #generate_token! and readable once, right after it, to show the admin.
  attr_reader :plain_token

  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true
  validate :scopes_are_known

  before_validation :generate_token!, on: :create, if: -> { token_digest.blank? }
  before_validation { self.scopes = (scopes || []).reject(&:blank?).uniq }

  scope :enabled, -> { where(enabled: true) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # Finds the enabled connection for a presented token, or nil.
  def self.authenticate(token)
    return if token.blank? || !token.start_with?(TOKEN_PREFIX)

    enabled.find_by(token_digest: digest(token))
  end

  # Issues a new token, replacing any previous one (which stops working on save).
  def generate_token!
    @plain_token = "#{TOKEN_PREFIX}#{SecureRandom.base58(40)}"
    self.token_digest = self.class.digest(@plain_token)
    self.token_prefix = @plain_token.first(12)
    self.token_generated_at = Time.current
    @plain_token
  end

  def regenerate_token!
    generate_token!
    save!
    @plain_token
  end

  def scope?(name)
    scopes.include?(name.to_s)
  end

  def touch_usage!(ip)
    update_columns(last_used_at: Time.current, last_used_ip: ip) if last_used_at.nil? || last_used_at < 1.minute.ago
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name enabled token_prefix last_used_at created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def scopes_are_known
    unknown = scopes - SCOPES.keys
    errors.add(:scopes, "contains unknown values: #{unknown.join(', ')}") if unknown.any?
  end
end
