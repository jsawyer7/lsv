class AddDualPassVeritalk < ActiveRecord::Migration[7.0]
  def change
    add_column :conversation_messages, :forensic_content, :text
    add_column :veritalk_validators, :purpose, :string, null: false, default: "forensic"
    add_index :veritalk_validators, :purpose
  end
end
