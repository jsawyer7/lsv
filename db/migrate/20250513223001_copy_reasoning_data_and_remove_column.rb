class CopyReasoningDataAndRemoveColumn < ActiveRecord::Migration[7.0]
  def up
    # Copy existing reasoning data to new table
    execute <<-SQL
      INSERT INTO reasonings (claim_id, source, response, result, created_at, updated_at)
      SELECT id, 'Quran', reasoning, result, created_at, updated_at
      FROM claims
      WHERE reasoning IS NOT NULL
    SQL
  end

  def down
    # Copy data back from the first Quran reasoning
    execute <<-SQL
      UPDATE claims c
      SET reasoning = (
        SELECT response 
        FROM reasonings r 
        WHERE r.claim_id = c.id 
        AND r.source = 'Quran' 
        LIMIT 1
      )
    SQL
  end
end 