class CreatePeers < ActiveRecord::Migration[7.0]
  def change
    create_table :peers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :peer, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'pending'
      t.timestamps
    end
    add_index :peers, [:user_id, :peer_id], unique: true
  end
end
