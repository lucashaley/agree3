class ContactMailer < ApplicationMailer
  def contact_email(name, email, message)
    @name = name
    @email = email
    @message = message

    mail(
      to: "lucashaley@yahoo.com",
      subject: "Contact Form Message from #{name}",
      reply_to: email
    )
  end
end
