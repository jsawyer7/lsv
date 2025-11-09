class RemoveCanonBooleanFieldsFromTextContents < ActiveRecord::Migration[7.0]
  def change
    remove_column :text_contents, :canon_catholic, :boolean
    remove_column :text_contents, :canon_protestant, :boolean
    remove_column :text_contents, :canon_lutheran, :boolean
    remove_column :text_contents, :canon_anglican, :boolean
    remove_column :text_contents, :canon_greek_orthodox, :boolean
    remove_column :text_contents, :canon_russian_orthodox, :boolean
    remove_column :text_contents, :canon_georgian_orthodox, :boolean
    remove_column :text_contents, :canon_western_orthodox, :boolean
    remove_column :text_contents, :canon_coptic, :boolean
    remove_column :text_contents, :canon_armenian, :boolean
    remove_column :text_contents, :canon_ethiopian, :boolean
    remove_column :text_contents, :canon_syriac, :boolean
    remove_column :text_contents, :canon_church_east, :boolean
    remove_column :text_contents, :canon_judaic, :boolean
    remove_column :text_contents, :canon_samaritan, :boolean
    remove_column :text_contents, :canon_lds, :boolean
    remove_column :text_contents, :canon_quran, :boolean
  end
end
