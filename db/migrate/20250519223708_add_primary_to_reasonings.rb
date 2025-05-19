class AddPrimaryToReasonings < ActiveRecord::Migration[7.0]
  def change
    add_column :reasonings, :primary_source, :boolean, default: false
  end
end
