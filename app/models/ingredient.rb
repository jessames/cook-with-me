class Ingredient < ApplicationRecord
  has_many :measurements
  belongs_to :ingredient_family, optional: true
end
