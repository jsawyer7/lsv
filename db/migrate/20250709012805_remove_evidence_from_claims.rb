class RemoveEvidenceFromClaims < ActiveRecord::Migration[7.0]
  def change
    remove_column :claims, :evidence, :text
  end
end
