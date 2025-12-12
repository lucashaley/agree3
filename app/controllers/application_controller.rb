class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :set_current_session

  private
    # Set current session if available (doesn't redirect if not authenticated)
    def set_current_session
      # Allow tests to set session via test_session_id header
      if Rails.env.test? && request.headers["X-Test-Session-ID"].present?
        session_id = request.headers["X-Test-Session-ID"]
      else
        session_id = cookies.signed[:session_token]
      end

      if session_record = Session.find_by_id(session_id)
        Current.session = session_record
      end
    end

    # Use this in controllers/actions that require authentication
    def require_authentication
      unless Current.session
        redirect_to sign_in_path
      end
    end

    def set_current_request_details
      Current.user_agent = request.user_agent
      Current.ip_address = request.ip
    end
end
