require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "contact_email" do
    name = "Test User"
    email = "test@example.com"
    message = "This is a test message"

    mail = ContactMailer.contact_email(name, email, message)

    assert_equal "Contact Form Message from Test User", mail.subject
    assert_equal [ "lucashaley@yahoo.com" ], mail.to
    assert_equal [ email ], mail.reply_to
    assert_match message, mail.body.encoded
  end
end
