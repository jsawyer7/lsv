class StaticController < ApplicationController
  layout 'application'

  before_action :load_alchemy_page, only: %i[privacy terms faq mission sources contact]

  def privacy; end
  def ai_data; end
  def terms; end
  def lsv; end
  def faq; end
  def mission; end
  def sources; end

  def contact; end

  def send_contact_message
    name    = params[:full_name]
    email   = params[:email]
    message = params[:message]

    if email.blank?
      flash[:alert] = 'Your email is mandatory.'
      redirect_to contact_path and return
    end

    ContactMailer.contact_email(name, email, message).deliver_now
    flash[:notice] = 'Your message has been sent!'
    redirect_to contact_path
  end

  private

  def load_alchemy_page
    urlname = {
      privacy: 'privacy',
      terms:   'terms',
      faq:     'faq',
      mission: 'mission',
      sources: 'sources',
      contact: 'contact',
    }[action_name.to_sym]

    return unless urlname

    @alchemy_page = Alchemy::Page
      .published
      .where(language: Alchemy::Language.default)
      .find_by(urlname: urlname)
  end
end
