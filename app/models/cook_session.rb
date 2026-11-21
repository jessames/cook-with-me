class CookSession < ApplicationRecord
  has_many :messages
  belongs_to :user
  belongs_to :recipe
  has_many :instruction
end
