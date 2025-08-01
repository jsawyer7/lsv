class Customer < ApplicationRecord
  belongs_to :user
  has_many :subscriptions, through: :user
  
  validates :chargebee_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  def full_name
    [first_name, last_name].compact.join(' ')
  end
  
  def display_name
    full_name.present? ? full_name : email
  end
end
