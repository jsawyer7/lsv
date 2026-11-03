class GrokBotConnectionPolicy < AdminPolicy
  def regenerate_token?
    user.admin?
  end

  def toggle?
    user.admin?
  end
end
