class CreateFoundationsOnly < ActiveRecord::Migration[7.0]
  def change
    create_table :foundations_only do |t|
      t.string :code
      t.string :title
      t.string :tradition_code
      t.string :lang_code
      t.string :scope
      t.string :pub_range
      t.text :citation_hint
      t.boolean :is_active

      t.timestamps
    end
  end
end
