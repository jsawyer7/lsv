class CreateAiEvidenceUsages < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_evidence_usages do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :used_at
      t.string :feature_type
      t.integer :usage_count

      t.timestamps
    end
  end
end
