class ContactMailer < ApplicationMailer
  default to: 'noreply@verifaith.com'

  def contact_email(name, email, message)
    @name = name
    @user_email = email
    @message = message
    mail(subject: "New Contact Message from "+(@name.presence || @user_email), from: (email.presence || 'noreply@verifaith.com'))
  end
end
 