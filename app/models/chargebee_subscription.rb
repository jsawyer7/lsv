class ChargebeeSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :chargebee_plan
  has_many :chargebee_billings, dependent: :destroy
end
