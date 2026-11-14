class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
    @ingredients = Ingredient.order(:name) if user_signed_in?
  end
end
