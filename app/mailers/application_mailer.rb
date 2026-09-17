class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_FROM', 'VeriFaith <noreply@verifaith.com>')
  layout 'mailer'
end
