class ChargebeePlan < ApplicationRecord
  has_many :chargebee_subscriptions, dependent: :destroy

  def entitlements
    metadata&.dig('entitlements') || []
  end

  def features
    entitlements.map { |entitlement| entitlement['feature_name'] }.compact
  end

  def feature_descriptions
    entitlements.map { |entitlement| entitlement['description'] }.compact
  end
end
