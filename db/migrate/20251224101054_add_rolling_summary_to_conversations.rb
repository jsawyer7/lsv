class AddRollingSummaryToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :rolling_summary, :text
    add_column :conversations, :last_summary_update_at, :datetime
    add_column :conversations, :message_count_since_summary, :integer
  end
end
