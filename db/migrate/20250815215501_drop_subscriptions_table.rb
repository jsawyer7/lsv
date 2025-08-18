class DropSubscriptionsTable < ActiveRecord::Migration[7.0]
  def up
    drop_table :subscriptions
  end

  def down
    create_table :subscriptions do |t|
      # ... (if you need to recreate it)
    end
  end
end
