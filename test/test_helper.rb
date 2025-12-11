ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  # Helper method for signing in users in integration tests
  def sign_in_as(user)
    # Create a session for the user
    session_record = user.sessions.create!
    @session_id = session_record.id
    user
  end

  # Override HTTP methods to inject the test session header
  [ :get, :post, :patch, :put, :delete ].each do |method|
    define_method(:"#{method}_with_session") do |path, **args|
      if defined?(@session_id) && @session_id
        args[:headers] ||= {}
        args[:headers]["X-Test-Session-ID"] = @session_id.to_s
      end
      send(:"#{method}_without_session", path, **args)
    end

    alias_method :"#{method}_without_session", method
    alias_method method, :"#{method}_with_session"
  end
end
