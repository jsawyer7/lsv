class CreateLanguages < ActiveRecord::Migration[7.0]
  def change
    create_table :languages do |t|
      t.string :code
      t.string :name
      t.string :iso_639_3
      t.string :script
      t.string :direction
      t.string :language_family
      t.text :notes

      t.timestamps
    end
  end
end
