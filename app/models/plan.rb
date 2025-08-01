class Plan < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error
  
  validates :chargebee_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :billing_cycle, presence: true, inclusion: { in: %w[monthly yearly one_time] }
  validates :status, presence: true, inclusion: { in: %w[active inactive] }
  
  scope :active, -> { where(status: 'active') }
  scope :by_price, -> { order(:price) }
  
  def free?
    price.zero?
  end
  
  def paid?
    price > 0
  end
  
  def feature_enabled?(feature_name)
    metadata&.dig('features', feature_name.to_s) == true
  end
  
  def features
    metadata&.dig('features') || {}
  end
end
