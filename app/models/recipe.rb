class Recipe < ApplicationRecord
  has_many :measurements
  has_many :ingredients, through: :measurements
  has_many :instructions
  has_many :cook_sessions
end
