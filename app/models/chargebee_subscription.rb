class ChargebeeSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :chargebee_plan
end
