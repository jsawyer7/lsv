class Peer < ApplicationRecord
  belongs_to :user
  belongs_to :peer, class_name: 'User'

  enum status: { pending: 'pending', accepted: 'accepted' }, _default: 'pending'

  scope :pending_requests, -> { where(status: 'pending') }
  scope :accepted_peers, -> { where(status: 'accepted') }
end
