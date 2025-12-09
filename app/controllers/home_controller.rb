class HomeController < ApplicationController
  def index
    @random_statement = Statement.order("RANDOM()").first
  end
end
