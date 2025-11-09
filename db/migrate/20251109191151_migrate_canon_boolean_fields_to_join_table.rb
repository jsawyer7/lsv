class MigrateCanonBooleanFieldsToJoinTable < ActiveRecord::Migration[7.0]
  def up
    # Mapping from canon codes to boolean field names
    code_to_field = {
      'CATH' => 'canon_catholic',
      'PROT' => 'canon_protestant',
      'ETH' => 'canon_ethiopian',
      'JEW' => 'canon_judaic',
      'ORTH' => 'canon_greek_orthodox',
      'CHR_LUTHERAN' => 'canon_lutheran',
      'CHR_ANGLICAN' => 'canon_anglican',
      'CHR_GREEK_ORTH' => 'canon_greek_orthodox',
      'CHR_RUSSIAN_ORTH' => 'canon_russian_orthodox',
      'CHR_GEORGIAN_ORTH' => 'canon_georgian_orthodox',
      'CHR_WESTERN_ORTH' => 'canon_western_orthodox',
      'CHR_COPTIC' => 'canon_coptic',
      'CHR_ARMENIAN' => 'canon_armenian',
      'CHR_ETHIOPIAN' => 'canon_ethiopian',
      'CHR_SYRIAC' => 'canon_syriac',
      'CHR_CHURCH_EAST' => 'canon_church_east',
      'HEB_SAMARITAN' => 'canon_samaritan',
      'CHR_LDS' => 'canon_lds',
      'ISL_QURAN' => 'canon_quran'
    }
    
    # Migrate data from boolean fields to join table
    TextContent.find_each do |text_content|
      code_to_field.each do |code, field|
        if text_content.send(field) == true
          canon = Canon.find_by(code: code)
          if canon
            CanonTextContent.find_or_create_by(
              text_content_id: text_content.id,
              canon_id: canon.id
            )
          end
        end
      end
    end
  end
  
  def down
    # Reverse migration: populate boolean fields from join table
    code_to_field = {
      'CATH' => 'canon_catholic',
      'PROT' => 'canon_protestant',
      'ETH' => 'canon_ethiopian',
      'JEW' => 'canon_judaic',
      'ORTH' => 'canon_greek_orthodox',
      'CHR_LUTHERAN' => 'canon_lutheran',
      'CHR_ANGLICAN' => 'canon_anglican',
      'CHR_GREEK_ORTH' => 'canon_greek_orthodox',
      'CHR_RUSSIAN_ORTH' => 'canon_russian_orthodox',
      'CHR_GEORGIAN_ORTH' => 'canon_georgian_orthodox',
      'CHR_WESTERN_ORTH' => 'canon_western_orthodox',
      'CHR_COPTIC' => 'canon_coptic',
      'CHR_ARMENIAN' => 'canon_armenian',
      'CHR_ETHIOPIAN' => 'canon_ethiopian',
      'CHR_SYRIAC' => 'canon_syriac',
      'CHR_CHURCH_EAST' => 'canon_church_east',
      'HEB_SAMARITAN' => 'canon_samaritan',
      'CHR_LDS' => 'canon_lds',
      'ISL_QURAN' => 'canon_quran'
    }
    
    TextContent.find_each do |text_content|
      # Reset all boolean fields to false
      code_to_field.values.uniq.each do |field|
        text_content.update_column(field, false)
      end
      
      # Set to true if association exists
      text_content.canons.each do |canon|
        field = code_to_field[canon.code.to_s]
        if field
          text_content.update_column(field, true)
        end
      end
    end
  end
end
