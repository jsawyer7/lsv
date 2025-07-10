class AddSourcesToEvidences < ActiveRecord::Migration[7.0]
  def change
    add_column :evidences, :sources, :integer, array: true, default: []
    add_index :evidences, :sources, using: 'gin'
    
    # Migrate existing single source to sources array
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE evidences 
          SET sources = ARRAY[source] 
          WHERE source IS NOT NULL
        SQL
      end
      
      dir.down do
        execute <<-SQL
          UPDATE evidences 
          SET source = sources[1] 
          WHERE array_length(sources, 1) > 0
        SQL
      end
    end
  end
end