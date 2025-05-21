class MakeReasoningPolymorphic < ActiveRecord::Migration[7.0]
  def change
    add_column :reasonings, :reasonable_type, :string
    add_column :reasonings, :reasonable_id, :bigint

    # Data migration: set reasonable_type to 'Claim' and reasonable_id to claim_id
    reversible do |dir|
      dir.up do
        Reasoning.reset_column_information
        Reasoning.find_each do |reasoning|
          reasoning.update_columns(
            reasonable_type: 'Claim',
            reasonable_id: reasoning.claim_id
          )
        end
      end
    end

    remove_reference :reasonings, :claim, foreign_key: true
    add_index :reasonings, [:reasonable_type, :reasonable_id, :source], unique: true, name: 'index_reasonings_on_reasonable_and_source'
  end
end
