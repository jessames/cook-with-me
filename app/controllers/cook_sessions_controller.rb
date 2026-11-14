class CookSessionsController < ApplicationController
  def new
    @cook_session = CookSession.new
    # a cook_session belongs to the logged in user,
  end

  def create
    # a new Cook Session iniates a new message
  end

  def destory

  end
end
