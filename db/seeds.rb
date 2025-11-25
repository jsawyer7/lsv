# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# Seed Party Types
puts "Seeding Party Types..."
party_types = [
  { code: 'INDIVIDUAL', label: 'Individual person', description: 'A specific individual person' },
  { code: 'ISRAEL', label: 'Nation of Israel', description: 'The nation of Israel as a whole' },
  { code: 'JUDAH', label: 'Kingdom of Judah', description: 'The kingdom of Judah' },
  { code: 'JEWS', label: 'Jews', description: 'Jewish people' },
  { code: 'GENTILES', label: 'Gentiles', description: 'Non-Jewish people' },
  { code: 'DISCIPLES', label: 'Disciples', description: 'Disciples of Jesus' },
  { code: 'BELIEVERS', label: 'Believers', description: 'Believers in general' },
  { code: 'ALL_PEOPLE', label: 'All people', description: 'All people universally' },
  { code: 'CHURCH', label: 'Specific church or assembly', description: 'A specific church or assembly (use custom_name for the church name)' },
  { code: 'NOT_SPECIFIED', label: 'Not specified in the text', description: 'The text does not specify a party' }
]

party_types.each do |pt|
  PartyType.find_or_create_by(code: pt[:code]) do |party_type|
    party_type.label = pt[:label]
    party_type.description = pt[:description]
  end
end
puts "✓ Party Types seeded"

# Seed Genre Types
puts "Seeding Genre Types..."
genre_types = [
  { code: 'NARRATIVE', label: 'Narrative', description: 'Narrative text' },
  { code: 'LAW', label: 'Law', description: 'Legal text, commandments, statutes' },
  { code: 'PROPHECY', label: 'Prophecy', description: 'Prophetic text' },
  { code: 'WISDOM', label: 'Wisdom', description: 'Wisdom literature' },
  { code: 'POETRY_SONG', label: 'Poetry / Song', description: 'Poetry or song' },
  { code: 'GOSPEL_TEACHING_SAYING', label: 'Gospel Teaching / Saying', description: 'Gospel teaching or saying' },
  { code: 'EPISTLE_LETTER', label: 'Epistle / Letter', description: 'Epistle or letter' },
  { code: 'APOCALYPTIC_VISION', label: 'Apocalyptic Vision', description: 'Apocalyptic vision' },
  { code: 'GENEALOGY_LIST', label: 'Genealogy / List', description: 'Genealogy or list' },
  { code: 'PRAYER', label: 'Prayer', description: 'Prayer text' }
]

genre_types.each do |gt|
  GenreType.find_or_create_by(code: gt[:code]) do |genre_type|
    genre_type.label = gt[:label]
    genre_type.description = gt[:description]
  end
end
puts "✓ Genre Types seeded"
