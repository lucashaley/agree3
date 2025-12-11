class HomeController < ApplicationController
  def index
    # Load 10 random statements for the carousel
    @statements = Statement.order("RANDOM()").limit(10)
  end
end
