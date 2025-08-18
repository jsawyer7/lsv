class ChargebeeBilling < ApplicationRecord
  belongs_to :user
  belongs_to :chargebee_subscription, optional: true

  validates :chargebee_id, presence: true, uniqueness: true
  validates :status, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(purchase_date: :desc) }
  scope :paid, -> { where(status: 'paid') }
  scope :pending, -> { where(status: 'pending') }
  scope :cancelled, -> { where(status: 'cancelled') }

  def paid?
    status == 'paid'
  end

  def pending?
    status == 'pending'
  end

  def cancelled?
    status == 'cancelled'
  end
end
