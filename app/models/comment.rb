class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true, length: { maximum: 5000 }

  scope :recent, -> { order(created_at: :desc) }

  # Scope to get comments visible to a specific user (peer network only)
  scope :visible_to, ->(viewer) {
    return none unless viewer

    # Comments are visible if:
    # 1. Viewer is the comment author
    # 2. Viewer is the commentable author (fact/theory owner)
    # 3. Viewer is a peer with the commentable author
    where(
      "comments.user_id = ? OR " \
      "(comments.commentable_type = 'Claim' AND EXISTS (SELECT 1 FROM claims WHERE claims.id = comments.commentable_id AND claims.user_id = ?)) OR " \
      "(comments.commentable_type = 'Theory' AND EXISTS (SELECT 1 FROM theories WHERE theories.id = comments.commentable_id AND theories.user_id = ?)) OR " \
      "(comments.commentable_type = 'Claim' AND EXISTS (SELECT 1 FROM claims INNER JOIN peers ON ((peers.user_id = ? AND peers.peer_id = claims.user_id) OR (peers.peer_id = ? AND peers.user_id = claims.user_id)) AND peers.status = 'accepted' WHERE claims.id = comments.commentable_id)) OR " \
      "(comments.commentable_type = 'Theory' AND EXISTS (SELECT 1 FROM theories INNER JOIN peers ON ((peers.user_id = ? AND peers.peer_id = theories.user_id) OR (peers.peer_id = ? AND peers.user_id = theories.user_id)) AND peers.status = 'accepted' WHERE theories.id = comments.commentable_id))",
      viewer.id, viewer.id, viewer.id, viewer.id, viewer.id, viewer.id, viewer.id
    )
  }

  # Class method to check if a comment is visible to a user
  def visible_to?(viewer)
    return false unless viewer

    # Viewer is the comment author
    return true if user_id == viewer.id

    # Get the commentable author
    commentable_author = case commentable_type
    when 'Claim'
      commentable&.user
    when 'Theory'
      commentable&.user
    else
      nil
    end

    return false unless commentable_author

    # Viewer is the commentable author
    return true if commentable_author.id == viewer.id

    # Check if viewer is a peer with the commentable author
    Peer.exists?(
      "((user_id = ? AND peer_id = ?) OR (peer_id = ? AND user_id = ?)) AND status = 'accepted'",
      viewer.id, commentable_author.id, viewer.id, commentable_author.id
    )
  end
end
