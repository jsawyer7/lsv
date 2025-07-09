class Evidence < ApplicationRecord
  belongs_to :claim

  enum source: {
    quran: 0,
    tanakh: 1,
    catholic: 2,
    ethiopian: 3,
    protestant: 4,
    historical: 5
  }
end
