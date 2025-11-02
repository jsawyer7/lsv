class AddSummaryAndDifferencesToTextTranslations < ActiveRecord::Migration[7.0]
  def change
    add_column :text_translations, :summary_and_differences, :text
  end
end

