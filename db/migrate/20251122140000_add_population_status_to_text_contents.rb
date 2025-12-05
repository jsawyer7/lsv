class AddPopulationStatusToTextContents < ActiveRecord::Migration[7.0]
  def change
    add_column :text_contents, :population_status, :string, default: 'pending'
    add_column :text_contents, :population_error_message, :text
    add_column :text_contents, :last_population_attempt_at, :datetime

    add_index :text_contents, :population_status
    add_index :text_contents, [:source_id, :population_status]
    add_index :text_contents, [:book_id, :population_status]
  end
end

