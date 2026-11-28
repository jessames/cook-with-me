class Ingredient < ApplicationRecord
  ROLES = %w[protein starch produce dairy aromatic seasoning].freeze

  has_many :measurements
  belongs_to :ingredient_family, optional: true
end
