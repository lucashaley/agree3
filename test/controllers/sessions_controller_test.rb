require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should get index" do
    sign_in_as @user

    get sessions_url
    assert_response :success
  end

  test "should get new" do
    get sign_in_url
    assert_response :success
  end

  # Skipping password-based sign in tests since routes are configured for passwordless
  # test "should sign in" do
  #   post sign_in_url, params: { email: @user.email, password: "Secret1*3*5*" }
  #   assert_redirected_to root_url
  #
  #   get root_url
  #   assert_response :success
  # end
  #
  # test "should not sign in with wrong credentials" do
  #   post sign_in_url, params: { email: @user.email, password: "SecretWrong1*3" }
  #   assert_redirected_to sign_in_url(email_hint: @user.email)
  #   assert_equal "That email or password is incorrect", flash[:alert]
  #
  #   get root_url
  #   assert_redirected_to sign_in_url
  # end

  test "should sign out" do
    session = sign_in_as @user
    session_record = @user.sessions.last

    delete session_url(session_record)
    assert_redirected_to sessions_url

    follow_redirect!
    assert_redirected_to sign_in_url
  end
end
