class NameMapping < ApplicationRecord
  validates :internal_id, presence: true, uniqueness: true
  validates :jewish, :christian, :muslim, :actual, :ethiopian, presence: true

  # Define ransackable attributes for ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    %w[id internal_id jewish christian muslim actual ethiopian created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  # Get all variations of names for this mapping
  def all_variations
    [jewish, christian, muslim, actual, ethiopian].compact.uniq
  end

  # Get the name for a specific tradition
  def name_for_tradition(tradition)
    case tradition.to_s.downcase
    when 'jewish'
      jewish
    when 'christian'
      christian
    when 'muslim'
      muslim
    when 'actual'
      actual
    when 'ethiopian'
      ethiopian
    else
      actual # default to actual
    end
  end

  # Check if this mapping contains a specific name
  def contains_name?(name)
    return false if name.blank?
    all_variations.any? { |variation| variation&.downcase == name.downcase }
  end
end 