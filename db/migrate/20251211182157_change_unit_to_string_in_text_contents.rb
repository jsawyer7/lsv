class ChangeUnitToStringInTextContents < ActiveRecord::Migration[7.0]
  def up
    # Change unit from integer to string to support sub-verses (e.g., "17a", "17b", "17c")
    # PostgreSQL will automatically cast existing integers to strings (e.g., 17 -> "17")
    # This is safe and preserves all existing data
    
    # Change the column type - PostgreSQL will automatically convert integers to strings
    # Using 'using' clause to explicitly cast integer to text
    change_column :text_contents, :unit, :string, using: 'unit::text'
  end

  def down
    # Convert string units back to integers (will lose sub-verse info like "17a" -> "17")
    # This is a destructive operation - only use if absolutely necessary
    # First, strip non-numeric characters from sub-verses
    execute <<-SQL
      UPDATE text_contents 
      SET unit = REGEXP_REPLACE(unit, '[^0-9]', '', 'g')
      WHERE unit ~ '[^0-9]';
    SQL
    
    # Then change column type back to integer
    change_column :text_contents, :unit, :integer, using: 'unit::integer'
  end
end
