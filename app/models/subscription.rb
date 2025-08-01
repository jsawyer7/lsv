class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :plan
  
  validates :chargebee_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[active cancelled past_due in_trial] }
  
  scope :active, -> { where(status: 'active') }
  scope :current, -> { where('current_term_end > ?', Time.current) }
  scope :expired, -> { where('current_term_end <= ?', Time.current) }
  
  def active?
    status == 'active'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def past_due?
    status == 'past_due'
  end
  
  def in_trial?
    status == 'in_trial'
  end
  
  def trial_active?
    trial_start.present? && trial_end.present? && Time.current.between?(trial_start, trial_end)
  end
  
  def current_period_active?
    current_term_start.present? && current_term_end.present? && 
    Time.current.between?(current_term_start, current_term_end)
  end
  
  def days_until_renewal
    return nil unless current_term_end
    (current_term_end - Time.current).to_i / 1.day
  end
end
