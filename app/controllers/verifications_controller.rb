class VerificationsController < ApplicationController
  def show
    @email = current_user&.email || session[:unconfirmed_email]
    redirect_to root_path if current_user&.confirmed?
  end

  def verify
    code = params[:code]&.join
    user = User.find_by(confirmation_token: code)

    if user&.confirm
      sign_in(user)
      redirect_to root_path, notice: "Email verified successfully!"
    else
      flash[:error] = "Invalid verification code. Please try again."
      redirect_to verify_email_path
    end
  end

  def resend
    user = User.find_by(email: session[:unconfirmed_email])
    
    if user&.send_confirmation_instructions
      flash[:notice] = "Verification code has been resent to your email."
    else
      flash[:error] = "Could not resend verification code. Please try again."
    end
    
    redirect_to verify_email_path
  end
end 