class ApplicationMailer < ActionMailer::Base
  default from: "postmaster@sandboxfb41615b753c431485dc9074dd0e0eee.mailgun.org"
  layout "mailer"
end
