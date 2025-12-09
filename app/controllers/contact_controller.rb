class ContactController < ApplicationController
  skip_before_action :authenticate

  def new
  end

  def create
    @name = params[:name]
    @email = params[:email]
    @message = params[:message]

    if @name.present? && @email.present? && @message.present?
      ContactMailer.contact_email(@name, @email, @message).deliver_later
      flash[:notice] = "Thank you for your message! I'll get back to you soon."
      redirect_to root_path
    else
      flash.now[:alert] = "Please fill in all fields."
      render :new, status: :unprocessable_entity
    end
  end
end
