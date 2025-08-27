class CreateMasterBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :master_books do |t|
      t.string :code
      t.string :title
      t.string :family_code
      t.string :origin_lang
      t.text :notes

      t.timestamps
    end
  end
end
