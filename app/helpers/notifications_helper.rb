module NotificationsHelper
  def notification_row_link(notification)
    return peers_path(tab: 'requests') if notification.key == 'peer_request'
    return notifications_path unless notification.notifiable.present?

    case notification.notifiable
    when Claim
      claim_path(notification.notifiable)
    when Theory
      theory_path(notification.notifiable)
    when Peer
      peers_path(tab: 'requests')
    else
      notifications_path
    end
  end

  def notification_message_html(notification)
    actor_name = notification.actor&.full_name.presence || notification.actor&.email || 'Someone'
    name_span = content_tag(:span, ERB::Util.html_escape(actor_name), class: 'notification-text-emphasis')

    case notification.key
    when 'fact_liked'
      content = notification.notifiable.respond_to?(:content) ? notification.notifiable.content.to_s.truncate(80) : ''
      content_span = content_tag(:span, "\"#{ERB::Util.html_escape(content)}\"", class: 'notification-text-emphasis')
      "#{name_span} liked your fact #{content_span}".html_safe
    when 'theory_liked'
      content = notification.notifiable.respond_to?(:title) ? notification.notifiable.title.to_s : ''
      content_span = content_tag(:span, "\"#{ERB::Util.html_escape(content)}\"", class: 'notification-text-emphasis')
      "#{name_span} liked your theory #{content_span}".html_safe
    when 'peer_request'
      "#{name_span} sent you a peer request.".html_safe
    else
      ERB::Util.html_escape(notification.display_message)
    end
  end

  def peer_request_notification?(notification)
    notification.key == 'peer_request'
  end
end
