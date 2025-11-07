class TextContentApiLog < ApplicationRecord
  belongs_to :text_content, optional: true

  validates :source_name, presence: true
  validates :book_code, presence: true
  validates :action, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source_name) { where(source_name: source_name) }
  scope :by_status, ->(status) { where(status: status) }
end

