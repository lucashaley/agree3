class Sessions::PasswordlessesController < ApplicationController
  before_action :set_user, only: :edit

  def new
  end

  def edit
    session_record = @user.sessions.create!
    cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

    revoke_tokens; redirect_to(root_path, notice: "Signed in successfully")
  end

  def create
    @user = User.find_by(email: params[:email])

    if @user.nil?
      # Create new user account with random password
      random_password = SecureRandom.base58(24)
      @user = User.create!(
        email: params[:email],
        password: random_password,
        password_confirmation: random_password,
        verified: false
      )
      send_email_verification
      redirect_to sign_in_path, notice: "Account created! Check your email to verify and sign in"
    elsif @user.verified?
      # Existing verified user - send passwordless sign-in link
      send_passwordless_email
      redirect_to sign_in_path, notice: "Check your email for sign in instructions"
    else
      # Existing unverified user - resend verification
      send_email_verification
      redirect_to sign_in_path, notice: "Check your email to verify your account"
    end
  end

  private
    def set_user
      token = SignInToken.find_signed!(params[:sid]); @user = token.user
    rescue StandardError
      redirect_to new_sessions_passwordless_path, alert: "That sign in link is invalid"
    end

    def send_passwordless_email
      UserMailer.with(user: @user).passwordless.deliver_later
    end

    def send_email_verification
      UserMailer.with(user: @user).email_verification.deliver_later
    end

    def revoke_tokens
      @user.sign_in_tokens.delete_all
    end
end
