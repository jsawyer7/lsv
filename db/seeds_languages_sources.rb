# Seed data for Languages, Sources, Books, Canons, and Canon-Books

puts "Creating Languages..."

# Create Languages
languages = [
  { code: 'grc', name: 'Greek', description: 'Koine Greek, NT manuscripts' },
  { code: 'heb', name: 'Hebrew', description: 'Biblical Hebrew, OT manuscripts' },
  { code: 'eng', name: 'English', description: 'Modern English translations' },
  { code: 'gez', name: 'Ge\'ez', description: 'Classical Ethiopic language' },
  { code: 'lat', name: 'Latin', description: 'Vulgate and Latin manuscripts' },
  { code: 'syr', name: 'Syriac', description: 'Syriac manuscripts and translations' }
]

languages.each do |lang_data|
  language = Language.find_or_create_by(code: lang_data[:code]) do |l|
    l.name = lang_data[:name]
    l.description = lang_data[:description]
  end
  puts "Created/Found Language: #{language.name} (#{language.code})"
end

puts "\nCreating Sources..."

# Create Sources
sources = [
  { code: 'NA28', name: 'Nestle-Aland 28th edition', language_code: 'grc', description: 'Critical Greek New Testament text' },
  { code: 'LXX_GOTT', name: 'Göttingen LXX', language_code: 'grc', description: 'Critical edition of the Septuagint' },
  { code: 'MT_BHS', name: 'Biblia Hebraica Stuttgartensia', language_code: 'heb', description: 'Critical Hebrew Bible text' },
  { code: 'KJV', name: 'King James Version', language_code: 'eng', description: 'Authorized Version of 1611' },
  { code: 'ESV', name: 'English Standard Version', language_code: 'eng', description: 'Modern English translation' },
  { code: 'VULGATE', name: 'Vulgate', language_code: 'lat', description: 'Latin Vulgate translation' },
  { code: 'PESHITTA', name: 'Peshitta', language_code: 'syr', description: 'Syriac Bible translation' }
]

sources.each do |source_data|
  language = Language.find_by(code: source_data[:language_code])
  source = Source.find_or_create_by(code: source_data[:code]) do |s|
    s.name = source_data[:name]
    s.description = source_data[:description]
    s.language = language
  end
  puts "Created/Found Source: #{source.name} (#{source.code}) - #{source.language.name}"
end

puts "\nCreating Books..."

# Create Books
books = [
  { code: 'GEN', std_name: 'Genesis', description: 'First book of the Torah' },
  { code: 'EXO', std_name: 'Exodus', description: 'Second book of the Torah' },
  { code: 'LEV', std_name: 'Leviticus', description: 'Third book of the Torah' },
  { code: 'NUM', std_name: 'Numbers', description: 'Fourth book of the Torah' },
  { code: 'DEU', std_name: 'Deuteronomy', description: 'Fifth book of the Torah' },
  { code: 'JOS', std_name: 'Joshua', description: 'Book of Joshua' },
  { code: 'JUD', std_name: 'Judges', description: 'Book of Judges' },
  { code: 'RUT', std_name: 'Ruth', description: 'Book of Ruth' },
  { code: '1SA', std_name: '1 Samuel', description: 'First book of Samuel' },
  { code: '2SA', std_name: '2 Samuel', description: 'Second book of Samuel' },
  { code: '1KI', std_name: '1 Kings', description: 'First book of Kings' },
  { code: '2KI', std_name: '2 Kings', description: 'Second book of Kings' },
  { code: '1CH', std_name: '1 Chronicles', description: 'First book of Chronicles' },
  { code: '2CH', std_name: '2 Chronicles', description: 'Second book of Chronicles' },
  { code: 'EZR', std_name: 'Ezra', description: 'Book of Ezra' },
  { code: 'NEH', std_name: 'Nehemiah', description: 'Book of Nehemiah' },
  { code: 'EST', std_name: 'Esther', description: 'Book of Esther' },
  { code: 'JOB', std_name: 'Job', description: 'Book of Job' },
  { code: 'PSA', std_name: 'Psalms', description: 'Book of Psalms' },
  { code: 'PRO', std_name: 'Proverbs', description: 'Book of Proverbs' },
  { code: 'ECC', std_name: 'Ecclesiastes', description: 'Book of Ecclesiastes' },
  { code: 'SNG', std_name: 'Song of Songs', description: 'Song of Solomon' },
  { code: 'ISA', std_name: 'Isaiah', description: 'Book of Isaiah' },
  { code: 'JER', std_name: 'Jeremiah', description: 'Book of Jeremiah' },
  { code: 'LAM', std_name: 'Lamentations', description: 'Book of Lamentations' },
  { code: 'EZK', std_name: 'Ezekiel', description: 'Book of Ezekiel' },
  { code: 'DAN', std_name: 'Daniel', description: 'Book of Daniel' },
  { code: 'HOS', std_name: 'Hosea', description: 'Book of Hosea' },
  { code: 'JOL', std_name: 'Joel', description: 'Book of Joel' },
  { code: 'AMO', std_name: 'Amos', description: 'Book of Amos' },
  { code: 'OBA', std_name: 'Obadiah', description: 'Book of Obadiah' },
  { code: 'JON', std_name: 'Jonah', description: 'Book of Jonah' },
  { code: 'MIC', std_name: 'Micah', description: 'Book of Micah' },
  { code: 'NAH', std_name: 'Nahum', description: 'Book of Nahum' },
  { code: 'HAB', std_name: 'Habakkuk', description: 'Book of Habakkuk' },
  { code: 'ZEP', std_name: 'Zephaniah', description: 'Book of Zephaniah' },
  { code: 'HAG', std_name: 'Haggai', description: 'Book of Haggai' },
  { code: 'ZEC', std_name: 'Zechariah', description: 'Book of Zechariah' },
  { code: 'MAL', std_name: 'Malachi', description: 'Book of Malachi' },
  # New Testament
  { code: 'MAT', std_name: 'Matthew', description: 'Gospel according to Matthew' },
  { code: 'MRK', std_name: 'Mark', description: 'Gospel according to Mark' },
  { code: 'LUK', std_name: 'Luke', description: 'Gospel according to Luke' },
  { code: 'JOH', std_name: 'John', description: 'Gospel according to John' },
  { code: 'ACT', std_name: 'Acts', description: 'Acts of the Apostles' },
  { code: 'ROM', std_name: 'Romans', description: 'Epistle to the Romans' },
  { code: '1CO', std_name: '1 Corinthians', description: 'First Epistle to the Corinthians' },
  { code: '2CO', std_name: '2 Corinthians', description: 'Second Epistle to the Corinthians' },
  { code: 'GAL', std_name: 'Galatians', description: 'Epistle to the Galatians' },
  { code: 'EPH', std_name: 'Ephesians', description: 'Epistle to the Ephesians' },
  { code: 'PHP', std_name: 'Philippians', description: 'Epistle to the Philippians' },
  { code: 'COL', std_name: 'Colossians', description: 'Epistle to the Colossians' },
  { code: '1TH', std_name: '1 Thessalonians', description: 'First Epistle to the Thessalonians' },
  { code: '2TH', std_name: '2 Thessalonians', description: 'Second Epistle to the Thessalonians' },
  { code: '1TI', std_name: '1 Timothy', description: 'First Epistle to Timothy' },
  { code: '2TI', std_name: '2 Timothy', description: 'Second Epistle to Timothy' },
  { code: 'TIT', std_name: 'Titus', description: 'Epistle to Titus' },
  { code: 'PHM', std_name: 'Philemon', description: 'Epistle to Philemon' },
  { code: 'HEB', std_name: 'Hebrews', description: 'Epistle to the Hebrews' },
  { code: 'JAS', std_name: 'James', description: 'Epistle of James' },
  { code: '1PE', std_name: '1 Peter', description: 'First Epistle of Peter' },
  { code: '2PE', std_name: '2 Peter', description: 'Second Epistle of Peter' },
  { code: '1JN', std_name: '1 John', description: 'First Epistle of John' },
  { code: '2JN', std_name: '2 John', description: 'Second Epistle of John' },
  { code: '3JN', std_name: '3 John', description: 'Third Epistle of John' },
  { code: 'JUD', std_name: 'Jude', description: 'Epistle of Jude' },
  { code: 'REV', std_name: 'Revelation', description: 'Book of Revelation' },
  # Deuterocanonical/Apocryphal
  { code: 'TOB', std_name: 'Tobit', description: 'Book of Tobit' },
  { code: 'JDT', std_name: 'Judith', description: 'Book of Judith' },
  { code: 'WIS', std_name: 'Wisdom', description: 'Book of Wisdom' },
  { code: 'SIR', std_name: 'Sirach', description: 'Book of Sirach' },
  { code: 'BAR', std_name: 'Baruch', description: 'Book of Baruch' },
  { code: '1MA', std_name: '1 Maccabees', description: 'First Book of Maccabees' },
  { code: '2MA', std_name: '2 Maccabees', description: 'Second Book of Maccabees' },
  { code: 'ENO1', std_name: '1 Enoch', description: 'First Book of Enoch' }
]

books.each do |book_data|
  book = Book.find_or_create_by(code: book_data[:code]) do |b|
    b.std_name = book_data[:std_name]
    b.description = book_data[:description]
  end
  puts "Created/Found Book: #{book.std_name} (#{book.code})"
end

puts "\nCreating Canons..."

# Create Canons
canons = [
  { code: 'CATH', name: 'Catholic', description: 'Roman Catholic canon, 73 books' },
  { code: 'PROT', name: 'Protestant', description: 'Protestant canon, 66 books' },
  { code: 'ETH', name: 'Ethiopian', description: 'Ethiopian Orthodox canon, 81 books' },
  { code: 'ORTH', name: 'Orthodox', description: 'Eastern Orthodox canon, 78 books' },
  { code: 'JEW', name: 'Jewish', description: 'Hebrew Bible/Tanakh, 24 books' }
]

canons.each do |canon_data|
  canon = Canon.find_or_create_by(code: canon_data[:code]) do |c|
    c.name = canon_data[:name]
    c.description = canon_data[:description]
  end
  puts "Created/Found Canon: #{canon.name} (#{canon.code})"
end

puts "\nCreating Canon-Book relationships..."

# Create some sample Canon-Book relationships
# Protestant Canon (66 books) - Old Testament (39 books)
protestant_ot_books = %w[GEN EXO LEV NUM DEU JOS JUD RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAH HAB ZEP HAG ZEC MAL]
protestant_nt_books = %w[MAT MRK LUK JOH ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV]

protestant_canon = Canon.find_by(code: 'PROT')
seq_no = 1

# Add Old Testament books
protestant_ot_books.each do |book_code|
  book = Book.find_by(code: book_code)
  if book
    canon_book = CanonBook.find_or_create_by(canon: protestant_canon, book: book) do |cb|
      cb.seq_no = seq_no
      cb.included_bool = true
    end
    puts "Added #{book.std_name} to Protestant canon at position #{seq_no}"
    seq_no += 1
  end
end

# Add New Testament books
protestant_nt_books.each do |book_code|
  book = Book.find_by(code: book_code)
  if book
    canon_book = CanonBook.find_or_create_by(canon: protestant_canon, book: book) do |cb|
      cb.seq_no = seq_no
      cb.included_bool = true
    end
    puts "Added #{book.std_name} to Protestant canon at position #{seq_no}"
    seq_no += 1
  end
end

# Catholic Canon (73 books) - includes Deuterocanonical books
catholic_canon = Canon.find_by(code: 'CATH')
catholic_books = %w[GEN EXO LEV NUM DEU JOS JUD RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH TOB JDT EST 1MA 2MA JOB PSA PRO ECC SNG WIS SIR ISA JER LAM BAR EZK DAN HOS JOL AMO OBA JON MIC NAH HAB ZEP HAG ZEC MAL MAT MRK LUK JOH ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV]

seq_no = 1
catholic_books.each do |book_code|
  book = Book.find_by(code: book_code)
  if book
    canon_book = CanonBook.find_or_create_by(canon: catholic_canon, book: book) do |cb|
      cb.seq_no = seq_no
      cb.included_bool = true
    end
    puts "Added #{book.std_name} to Catholic canon at position #{seq_no}"
    seq_no += 1
  end
end

puts "\nSeed data creation completed!"
puts "Created #{Language.count} languages"
puts "Created #{Source.count} sources"
puts "Created #{Book.count} books"
puts "Created #{Canon.count} canons"
puts "Created #{CanonBook.count} canon-book relationships"
