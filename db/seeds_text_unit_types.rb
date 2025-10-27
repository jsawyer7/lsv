# Seed data for Text Unit Types
puts "Creating Text Unit Types..."

text_unit_types_data = [
  {
    code: "BIB_CHAPTER",
    name: "Chapter",
    description: "Used for all chapter-based sources (Bible, LDS, etc.)"
  },
  {
    code: "BIB_VERSE",
    name: "Verse",
    description: "Used for all verse-level units (Bible, LDS, etc.)"
  },
  {
    code: "QUR_SURA",
    name: "Surah",
    description: "Qur'an chapter unit"
  },
  {
    code: "QUR_AYAH",
    name: "Ayah",
    description: "Qur'an verse unit"
  },
  {
    code: "ETH_HOMILY",
    name: "Homily Section",
    description: "Ge'ez Sinodos or liturgical unit"
  },
  {
    code: "GEN_SECTION",
    name: "Section / Paragraph",
    description: "Used when a work isn't verse-structured (e.g., Enoch, Jubilees, Josephus)"
  }
]

text_unit_types_data.each do |data|
  text_unit_type = TextUnitType.find_or_create_by(code: data[:code]) do |t|
    t.name = data[:name]
    t.description = data[:description]
  end
  
  if text_unit_type.persisted?
    puts "✓ Created Text Unit Type: #{text_unit_type.name} (#{text_unit_type.code})"
  else
    puts "✗ Failed to create Text Unit Type: #{data[:name]} - #{text_unit_type.errors.full_messages.join(', ')}"
  end
end

puts "Text Unit Types seeding completed!"
puts "Total Text Unit Types: #{TextUnitType.count}"
