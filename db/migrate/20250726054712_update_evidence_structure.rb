class UpdateEvidenceStructure < ActiveRecord::Migration[7.0]
  def change
    # Keep content column for storing JSON evidence sections
    # Add structured fields for each evidence type
    add_column :evidences, :verse_reference, :string
    add_column :evidences, :original_text, :text
    add_column :evidences, :translation, :text
    add_column :evidences, :explanation, :text
    add_column :evidences, :historical_event, :string
    add_column :evidences, :description, :text
    add_column :evidences, :relevance, :text
    add_column :evidences, :term, :string
    add_column :evidences, :definition, :text
    add_column :evidences, :etymology, :text
    add_column :evidences, :usage_context, :text
    add_column :evidences, :premise, :text
    add_column :evidences, :reasoning, :text
    add_column :evidences, :conclusion, :text
    add_column :evidences, :logical_form, :string
  end
end
