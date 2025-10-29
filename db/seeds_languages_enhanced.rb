# Enhanced seed data for Languages with script-specific details
puts "Creating Languages with script-specific details..."

# Get directions
ltr_direction = Direction.find_by(code: 'LTR')
rtl_direction = Direction.find_by(code: 'RTL')

languages_data = [
  {
    code: "grc",
    name: "Greek",
    description: "Koine Greek, NT manuscripts",
    direction: ltr_direction,
    script: "Greek",
    font_stack: "SBL Greek, New Athena Unicode, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: false,
    uses_diacritics: true,
    has_cantillation: false,
    has_ayah_markers: false,
    native_digits: false,
    punctuation_mirroring: false
  },
  {
    code: "heb",
    name: "Hebrew",
    description: "Biblical Hebrew, Masoretic Text",
    direction: rtl_direction,
    script: "Hebrew",
    font_stack: "SBL Hebrew, Ezra SIL, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: false,
    uses_diacritics: true,
    has_cantillation: true,
    has_ayah_markers: false,
    native_digits: false,
    punctuation_mirroring: true
  },
  {
    code: "ara",
    name: "Arabic",
    description: "Classical Arabic, Quran",
    direction: rtl_direction,
    script: "Arabic",
    font_stack: "KFGQPC Uthmanic, Scheherazade, Amiri, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: true,
    uses_diacritics: true,
    has_cantillation: false,
    has_ayah_markers: true,
    native_digits: true,
    punctuation_mirroring: true
  },
  {
    code: "syr",
    name: "Syriac",
    description: "Classical Syriac, Peshitta",
    direction: rtl_direction,
    script: "Syriac",
    font_stack: "SBL Syriac, Meltho, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: true,
    uses_diacritics: true,
    has_cantillation: false,
    has_ayah_markers: false,
    native_digits: false,
    punctuation_mirroring: true
  },
  {
    code: "gez",
    name: "Ge'ez",
    description: "Classical Ethiopic, Ge'ez",
    direction: ltr_direction,
    script: "Ethiopic",
    font_stack: "Abyssinica SIL, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: false,
    uses_diacritics: false,
    has_cantillation: false,
    has_ayah_markers: false,
    native_digits: true,
    punctuation_mirroring: false
  },
  {
    code: "eng",
    name: "English",
    description: "Modern English translations",
    direction: ltr_direction,
    script: "Latin",
    font_stack: "serif",
    unicode_normalization: "NFC",
    shaping_engine: nil,
    has_joining: false,
    uses_diacritics: false,
    has_cantillation: false,
    has_ayah_markers: false,
    native_digits: false,
    punctuation_mirroring: false
  },
  {
    code: "arm",
    name: "Armenian",
    description: "Classical Armenian",
    direction: ltr_direction,
    script: "Armenian",
    font_stack: "Noto Serif Armenian, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: false,
    uses_diacritics: false,
    has_cantillation: false,
    has_ayah_markers: false,
    native_digits: false,
    punctuation_mirroring: false
  },
  {
    code: "cop",
    name: "Coptic",
    description: "Coptic language",
    direction: ltr_direction,
    script: "Coptic",
    font_stack: "NewCoptic, Noto Sans Coptic, serif",
    unicode_normalization: "NFC",
    shaping_engine: "HarfBuzz",
    has_joining: false,
    uses_diacritics: false,
    has_cantillation: false,
    has_ayah_markers: false,
    native_digits: false,
    punctuation_mirroring: false
  }
]

languages_data.each do |data|
  language = Language.find_or_create_by(code: data[:code]) do |l|
    l.name = data[:name]
    l.description = data[:description]
    l.direction = data[:direction]
    l.script = data[:script]
    l.font_stack = data[:font_stack]
    l.unicode_normalization = data[:unicode_normalization]
    l.shaping_engine = data[:shaping_engine]
    l.has_joining = data[:has_joining]
    l.uses_diacritics = data[:uses_diacritics]
    l.has_cantillation = data[:has_cantillation]
    l.has_ayah_markers = data[:has_ayah_markers]
    l.native_digits = data[:native_digits]
    l.punctuation_mirroring = data[:punctuation_mirroring]
  end
  
  if language.persisted?
    puts "✓ Created Language: #{language.name} (#{language.code}) - #{language.direction&.name}"
  else
    puts "✗ Failed to create Language: #{data[:name]} - #{language.errors.full_messages.join(', ')}"
  end
end

puts "Languages seeding completed!"
puts "Total Languages: #{Language.count}"
