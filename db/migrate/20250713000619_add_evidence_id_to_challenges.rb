class AddEvidenceIdToChallenges < ActiveRecord::Migration[7.0]
  def change
    add_reference :challenges, :evidence, null: false, foreign_key: true
  end
end
