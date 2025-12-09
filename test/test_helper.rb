ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def sign_in_as(user, password: "Secret1*3*5*")
    post(sign_in_url, params: { email: user.email, password: password }); user
  end
end

class ActionDispatch::IntegrationTest
  # Helper method for signing in users in integration tests
  def sign_in_user(user)
    # Create a session for the user
    session_record = user.sessions.create!

    # In test environment, we'll set the session via the test_session_id approach
    # Use post_via_redirect to set the session and follow through
    @test_session_id = session_record.id

    # Make an initial request to set up the session
    get root_path
  end

  # Override the get/post/etc methods to inject the test session
  [:get, :post, :patch, :put, :delete].each do |method|
    define_method(:"#{method}_with_test_session") do |path, **args|
      if defined?(@test_session_id) && @test_session_id
        # Inject session data through headers that our authenticate method can read
        args[:headers] ||= {}
        args[:headers]['X-Test-Session-ID'] = @test_session_id.to_s
      end
      send(:"#{method}_without_test_session", path, **args)
    end

    alias_method :"#{method}_without_test_session", method
    alias_method method, :"#{method}_with_test_session"
  end
end
