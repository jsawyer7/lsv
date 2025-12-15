class Share < ApplicationRecord
  belongs_to :user
  belongs_to :shareable, polymorphic: true
  belongs_to :recipient, class_name: 'User', optional: true

  validates :user_id, uniqueness: {
    scope: [:recipient_id, :shareable_type, :shareable_id],
    message: "has already shared this item with this recipient"
  }, if: -> { recipient_id.present? }

  # For reshared items (public feed), recipient_id is nil
  scope :reshared, -> { where(recipient_id: nil) }
  scope :peer_shares, -> { where.not(recipient_id: nil) }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_read!
    update(read_at: Time.current) unless read_at?
  end
end
