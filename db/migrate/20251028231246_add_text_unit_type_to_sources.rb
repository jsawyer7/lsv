class AddTextUnitTypeToSources < ActiveRecord::Migration[7.0]
  def change
    add_reference :sources, :text_unit_type, null: true, foreign_key: true
  end
end
