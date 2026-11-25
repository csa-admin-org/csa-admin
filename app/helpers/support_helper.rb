# frozen_string_literal: true

module SupportHelper
  CONVERT_PAIR_GAP = 30.seconds

  def ticket_admins_collection(relation = nil)
    collection = Admin.order_by_name
    if relation
      admin_ids = relation.unscope(where: "#{relation.klass.table_name}.admin_id").unscope(:limit, :offset).distinct.pluck(:admin_id)
      collection = collection.where(id: admin_ids)
    end
    collection
  end

  def ticket_priority_marks_collection
    [
      [ "", :normal ],
      [ Support::Ticket::PRIORITY_ICONS[:medium], :medium ],
      [ Support::Ticket::PRIORITY_ICONS[:high], :high ]
    ]
  end

  def ticket_priority_filter_collection
    ticket_priority_marks_collection.map { |label, key|
      [ label, Support::Ticket.priorities[key] ]
    }
  end

  def support_message_html(message)
    html = if message.html.present?
      source = rendered_action_text(message)
      message.author_admin? ? Support::ReplyHtml.present(source) : Support::ReplyHtml.strip_styles(source)
    else
      text = message.author_admin? ? Support::ReplyBody.without_quote(message.body) : message.body
      Support::MessageFormat.to_html(text)
    end
    Support::AppLink.rewrite(Support::MessageHtml.rewrite(html))
  end

  def support_message_attachments(message)
    images, files = split_support_attachments(message.attachments)
    opening, reply = convert_pair(message)
    if opening && reply && message.id == opening.id
      files += split_support_attachments(reply.attachments).last
    elsif opening && reply && message.id == reply.id
      files = []
    end
    [ images, files ]
  end

  def support_previewable_image?(file)
    file.attached? && Support::InboundAttachments::IMAGE_TYPES.include?(file.content_type.to_s.downcase.split(";").first)
  end

  def support_inline_image(file)
    link_to(url_for(file), target: "_blank", rel: "noopener") do
      image_tag file.variant(resize_to_limit: [ 960, 960 ]),
        class: "support-message-image",
        alt: file.filename.to_s
    end
  end

  def support_inbox_empty?
    return false unless respond_to?(:active_admin_config)
    return false unless active_admin_config.resource_class == Support::Ticket
    return false if params[:q].present?

    (params[:scope].presence || "all").in?(%w[all waiting])
  end

  private

  def rendered_action_text(message)
    ActionTextHtml.unwrap_attachments(render_action_text_content(message.html.body))
  end

  def split_support_attachments(attachments)
    attachments.partition { |attachment| support_previewable_image?(attachment.file) }
  end

  # Pre-fix converts stored the original email's files on the support reply
  # that was inserted with the opening admin message.
  def convert_pair(message)
    ticket = message.ticket
    return unless ticket

    opening, reply = ticket.messages.to_a.select(&:persisted?).sort_by(&:id).first(2)
    return unless opening&.author_admin? && reply&.author_support?
    return unless opening.rfc_message_id.blank?
    return unless opening.created_at && reply.created_at
    return unless (reply.created_at - opening.created_at).abs <= CONVERT_PAIR_GAP

    [ opening, reply ]
  end
end
