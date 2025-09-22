class StaticController < ApplicationController
  layout 'application'

  def privacy; end
  def ai_data; end
  def terms; end
  def lsv; end
  def faq; end
  def mission; end
  def sources; end

  def contact
  end

  def send_contact_message
    name = params[:full_name]
    email = params[:email]
    message = params[:message]
    if email.blank?
      flash[:alert] = 'Your email is mandatory.'
      redirect_to contact_path
      return
    end
    ContactMailer.contact_email(name, email, message).deliver_now
    flash[:notice] = 'Your message has been sent!'
    redirect_to contact_path
  end
end
