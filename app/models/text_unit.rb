class TextUnit < ApplicationRecord
  self.primary_key = 'unit_id'
  
  validates :unit_id, presence: true, uniqueness: true
  validates :tradition, presence: true
  validates :work_code, presence: true
  validates :division_code, presence: true
  validates :chapter, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :verse, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :tradition, uniqueness: { scope: [:division_code, :chapter, :verse, :subref] }
  
  # Associations
  has_many :canon_maps, foreign_key: 'unit_id', primary_key: 'unit_id', dependent: :destroy
  has_many :text_payloads, foreign_key: 'unit_id', primary_key: 'unit_id', dependent: :destroy
  
  # Canonical identifiers for Quran
  QURAN_TRADITION = 'quran'
  QURAN_WORK_CODE = 'QURAN'
  
  # Surah names mapping (canonical transliterated names)
  SURAH_NAMES = {
    1 => 'AlFatiha',
    2 => 'AlBaqarah',
    3 => 'AlImran',
    4 => 'AnNisa',
    5 => 'AlMaidah',
    6 => 'AlAnam',
    7 => 'AlAraf',
    8 => 'AlAnfal',
    9 => 'AtTawbah',
    10 => 'Yunus',
    11 => 'Hud',
    12 => 'Yusuf',
    13 => 'ArRad',
    14 => 'Ibrahim',
    15 => 'AlHijr',
    16 => 'AnNahl',
    17 => 'AlIsra',
    18 => 'AlKahf',
    19 => 'Maryam',
    20 => 'Taha',
    21 => 'AlAnbiya',
    22 => 'AlHajj',
    23 => 'AlMuminun',
    24 => 'AnNur',
    25 => 'AlFurqan',
    26 => 'AshShuara',
    27 => 'AnNaml',
    28 => 'AlQasas',
    29 => 'AlAnkabut',
    30 => 'ArRum',
    31 => 'Luqman',
    32 => 'AsSajdah',
    33 => 'AlAhzab',
    34 => 'Saba',
    35 => 'Fatir',
    36 => 'YaSin',
    37 => 'AsSaffat',
    38 => 'Sad',
    39 => 'AzZumar',
    40 => 'Ghafir',
    41 => 'Fussilat',
    42 => 'AshShura',
    43 => 'AzZukhruf',
    44 => 'AdDukhan',
    45 => 'AlJathiyah',
    46 => 'AlAhqaf',
    47 => 'Muhammad',
    48 => 'AlFath',
    49 => 'AlHujurat',
    50 => 'Qaf',
    51 => 'AdhDhariyat',
    52 => 'AtTur',
    53 => 'AnNajm',
    54 => 'AlQamar',
    55 => 'ArRahman',
    56 => 'AlWaqiah',
    57 => 'AlHadid',
    58 => 'AlMujadilah',
    59 => 'AlHashr',
    60 => 'AlMumtahanah',
    61 => 'AsSaff',
    62 => 'AlJumuah',
    63 => 'AlMunafiqun',
    64 => 'AtTaghabun',
    65 => 'AtTalaq',
    66 => 'AtTahrim',
    67 => 'AlMulk',
    68 => 'AlQalam',
    69 => 'AlHaqqah',
    70 => 'AlMaarij',
    71 => 'Nuh',
    72 => 'AlJinn',
    73 => 'AlMuzzammil',
    74 => 'AlMuddaththir',
    75 => 'AlQiyamah',
    76 => 'AlInsan',
    77 => 'AlMursalat',
    78 => 'AnNaba',
    79 => 'AnNaziat',
    80 => 'Abasa',
    81 => 'AtTakwir',
    82 => 'AlInfitar',
    83 => 'AlMutaffifin',
    84 => 'AlInshiqaq',
    85 => 'AlBuruj',
    86 => 'AtTariq',
    87 => 'AlAla',
    88 => 'AlGhashiyah',
    89 => 'AlFajr',
    90 => 'AlBalad',
    91 => 'AshShams',
    92 => 'AlLayl',
    93 => 'AdDuha',
    94 => 'AshSharh',
    95 => 'AtTin',
    96 => 'AlAlaq',
    97 => 'AlQadr',
    98 => 'AlBayyinah',
    99 => 'AzZalzalah',
    100 => 'AlAdiyat',
    101 => 'AlQariah',
    102 => 'AtTakathur',
    103 => 'AlAsr',
    104 => 'AlHumazah',
    105 => 'AlFil',
    106 => 'Quraysh',
    107 => 'AlMaun',
    108 => 'AlKawthar',
    109 => 'AlKafirun',
    110 => 'AnNasr',
    111 => 'AlMasad',
    112 => 'AlIkhlas',
    113 => 'AlFalaq',
    114 => 'AnNas'
  }.freeze
  
  def self.surah_name(surah_number)
    SURAH_NAMES[surah_number]
  end
end
