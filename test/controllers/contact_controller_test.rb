require "test_helper"

class ContactControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get contact_form_url
    assert_response :success
  end

  test "should post create and enqueue email" do
    assert_enqueued_emails 1 do
      post contact_url, params: {
        name: "Test User",
        email: "test@example.com",
        message: "Test message"
      }
    end
    assert_redirected_to root_url
  end

  test "should not create with missing fields" do
    assert_no_enqueued_emails do
      post contact_url, params: {
        name: "",
        email: "test@example.com",
        message: ""
      }
    end
    assert_response :unprocessable_entity
  end
end
