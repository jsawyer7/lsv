class AddLsvLiteralReconstructionToTextContents < ActiveRecord::Migration[7.0]
  def change
    add_column :text_contents, :lsv_literal_reconstruction, :text
  end
end

