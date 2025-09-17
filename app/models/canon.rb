class Canon < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :domain_code, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }
  validates :is_official, inclusion: { in: [true, false] }

  # Associations
  has_many :canon_book_inclusions, dependent: :destroy
  has_many :canon_work_preferences, dependent: :destroy

  # Through associations to master_books
  has_many :included_books, through: :canon_book_inclusions, source: :master_book
  has_many :preferred_books, through: :canon_work_preferences, source: :master_book

  # Override destroy to handle composite primary keys properly
  def destroy
    ActiveRecord::Base.transaction do
      # Manually delete associated records with composite primary keys
      # Using delete_all for better performance and to avoid composite key issues
      CanonBookInclusion.where(canon_id: id).delete_all
      CanonWorkPreference.where(canon_id: id).delete_all

      # Then destroy the canon itself
      super
    end
  rescue => e
    # Log the error and re-raise it
    Rails.logger.error "Error destroying canon #{id}: #{e.message}"
    raise e
  end

  # Domain association (assuming there's a domains table)
  # belongs_to :domain, foreign_key: 'domain_code', primary_key: 'code'


  scope :official, -> { where(is_official: true) }
  scope :ordered, -> { order(:display_order, :name) }

  def self.ransackable_attributes(auth_object = nil)
    ["code", "created_at", "description", "display_order", "domain_code", "id", "is_official", "name", "updated_at"]
  end
end
