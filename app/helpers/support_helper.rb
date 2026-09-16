# frozen_string_literal: true

module SupportHelper
  def ticket_admins_collection(relation = nil)
    collection = Admin.order_by_name
    if relation
      admin_ids = relation.unscope(where: :admin_id).unscope(:limit, :offset).distinct.pluck(:admin_id)
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
      message.html.to_s
    else
      Support::MessageFormat.to_html(message.body)
    end
    Support::AppLink.rewrite(Support::MessageHtml.rewrite(html))
  end

  def support_message_attachments(message)
    message.attachments.partition { |attachment|
      support_previewable_image?(attachment.file)
    }
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
end
