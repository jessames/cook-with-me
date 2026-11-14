class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    #@ingredients = Ingredient.order(:name) if user_signed_in?
    @ingredients = if user_signed_in?
      [
        Ingredient.new(id: 1, name: "Chicken"),
        Ingredient.new(id: 2, name: "Tomato"),
        Ingredient.new(id: 3, name: "Onion"),
        Ingredient.new(id: 4, name: "Garlic"),
        Ingredient.new(id: 5, name: "Potato")
      ]
    end
  end
end
