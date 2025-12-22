class TextContentApiLog < ApplicationRecord
  belongs_to :text_content, optional: true

  validates :source_name, presence: true
  validates :book_code, presence: true
  validates :action, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source_name) { where(source_name: source_name) }
  scope :by_status, ->(status) { where(status: status) }
  scope :populate_jobs, -> { where(action: 'populate_job') }
  scope :failed, -> { where(status: ['error', 'needs_repair', 'unavailable']) }
  scope :successful, -> { where(status: ['success', 'provisional_ok', 'already_populated']) }

  # Get failed populate jobs that can be retried
  def self.failed_populate_jobs(limit: nil)
    scope = populate_jobs.failed.order(created_at: :desc)
    scope = scope.limit(limit) if limit
    scope
  end

  # Re-enqueue failed jobs for retry
  def self.retry_failed_jobs(limit: nil, force: false)
    failed = failed_populate_jobs(limit: limit)
    count = 0
    
    failed.find_each do |log|
      next unless log.text_content_id
      
      text_content = TextContent.unscoped.find_by(id: log.text_content_id)
      next unless text_content
      
      TextContentPopulateJob.perform_later(text_content.id, force: force)
      count += 1
    end
    
    count
  end

  # Get summary of failed jobs grouped by error
  def self.failed_job_summary
    failed_populate_jobs.group(:error_message).count
      .sort_by { |_, count| -count }
      .first(20)
  end
end

