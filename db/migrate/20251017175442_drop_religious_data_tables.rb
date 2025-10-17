class DropReligiousDataTables < ActiveRecord::Migration[7.0]
  def change
    # Drop tables in reverse dependency order to avoid foreign key constraints

    # Drop junction tables first
    drop_table :canon_book_inclusions, if_exists: true
    drop_table :canon_work_preferences, if_exists: true
    drop_table :canon_maps, if_exists: true
    drop_table :numbering_labels, if_exists: true
    drop_table :numbering_maps, if_exists: true
    drop_table :text_payloads, if_exists: true

    # Drop main tables
    drop_table :canons, if_exists: true
    drop_table :families_for_foundations, if_exists: true
    drop_table :families_seed, if_exists: true
    drop_table :foundations_only, if_exists: true
    drop_table :languages, if_exists: true
    drop_table :master_books, if_exists: true
    drop_table :numbering_systems, if_exists: true
    drop_table :source_registries, if_exists: true
    drop_table :text_units, if_exists: true
  end
end
