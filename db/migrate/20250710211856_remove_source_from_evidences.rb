class RemoveSourceFromEvidences < ActiveRecord::Migration[7.0]
  def change
    remove_column :evidences, :source, :integer
  end
end
