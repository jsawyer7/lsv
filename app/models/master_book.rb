class MasterBook < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :family_code, presence: true
  validates :origin_lang, presence: true
end
