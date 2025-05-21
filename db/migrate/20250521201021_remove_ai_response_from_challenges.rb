class RemoveAiResponseFromChallenges < ActiveRecord::Migration[7.0]
  def change
    remove_column :challenges, :ai_response, :text
  end
end
