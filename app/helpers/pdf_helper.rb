# frozen_string_literal: true

module PDFHelper
  def pdf_stylesheet_tags(*names)
    sghtmltopdf_stylesheet_link_tag("pdf/base", *names)
  end

  def format_delivery_change_details(details)
    return if details.nil?

    segments = details.split(Delivery::Changes::EMPTY_LABEL).each_with_index.map do |part, index|
      if index.odd?
        tag.span(part, class: "delivery-change-empty")
      else
        safe_join(part.split("\n", -1), tag.br)
      end
    end
    safe_join(segments)
  end

  def sanitize_invoice_footer(footer)
    return if footer.blank?

    sanitize(footer.to_s.gsub("\n", "<br>"), tags: %w[b strong i em u br], attributes: [])
  end
end
