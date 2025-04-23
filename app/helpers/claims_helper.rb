module ClaimsHelper
  def claim_status_class(status)
    case status&.downcase
    when 'true'
      'success'
    when 'false'
      'danger'
    else
      'neutral'
    end
  end
end 