# frozen_string_literal: true

module SearchHelper
  # Highlights matching substrings in +text+ based on the search +query+.
  #
  # Builds a "compact" string (alphanumeric + spaces only) with a position
  # mapping back to the original text, so that punctuation like thousands
  # separators (e.g. 1'416) doesn't break matching — "14" correctly
  # highlights "1'4" in "CHF 1'416.00".
  #
  #   highlight_search("René Müller", "rene")
  #   # => "<mark>René</mark> Müller"
  #
  #   highlight_search("CHF 1'416.00", "14")
  #   # => "CHF <mark>1'4</mark>16.00"
  #
  def highlight_search(text, query)
    return "".html_safe if text.blank?

    text = text.to_s
    return ERB::Util.html_escape(text) if query.blank? || query.length < 2

    # Strip punctuation from terms to match the compact string where
    # non-alphanumeric chars are removed (e.g. "chaux-de-fonds" → "chauxdefonds").
    terms = SearchEntry.search_terms(query).map { |t| t.gsub(/[^a-z0-9]/, "") }
    terms.reject!(&:blank?)
    return ERB::Util.html_escape(text) if terms.empty?

    # Build a compact string (lowercase, unaccented, alphanumeric + spaces)
    # with a mapping from each compact index back to the original text index.
    compact = +""
    compact_to_orig = []

    text.each_char.with_index do |char, orig_idx|
      ActiveSupport::Inflector.transliterate(char, locale: :en).downcase.each_char do |nc|
        if nc.match?(/[a-z0-9 ]/)
          compact << nc
          compact_to_orig << orig_idx
        end
      end
    end

    # Find all match positions in the compact string, mapped back to original
    positions = []
    terms.each do |term|
      search_from = 0
      while (idx = compact.index(term, search_from))
        orig_start = compact_to_orig[idx]
        orig_end = compact_to_orig[idx + term.length - 1] + 1
        positions << [ orig_start, orig_end ]
        search_from = idx + 1
      end
    end

    return ERB::Util.html_escape(text) if positions.empty?

    # Sort by start position, then merge overlapping/adjacent ranges
    positions.sort_by!(&:first)
    merged = [ positions.first.dup ]
    positions[1..].each do |start_pos, end_pos|
      if start_pos <= merged.last[1]
        merged.last[1] = [ merged.last[1], end_pos ].max
      else
        merged << [ start_pos, end_pos ]
      end
    end

    # Build the highlighted string from original text using merged positions
    result = +""
    last_end = 0
    merged.each do |start_pos, end_pos|
      result << ERB::Util.html_escape(text[last_end...start_pos]) if start_pos > last_end
      result << "<mark>#{ERB::Util.html_escape(text[start_pos...end_pos])}</mark>"
      last_end = end_pos
    end
    result << ERB::Util.html_escape(text[last_end..]) if last_end < text.length

    result.html_safe
  end

  # Returns a hash of locals for rendering a unified search result partial.
  #
  # Each record type is mapped to a consistent set of attributes:
  #   icon_name   - icon name (matches the site header menu icons)
  #   url         - link target
  #   title       - raw text, the partial will apply highlight_search
  #   subtitle_parts - array of HTML-safe parts (joined with " · " in the partial)
  #   state       - raw state string for data-status attribute (nil if no badge)
  #   state_label - translated badge text (nil if no badge)
  #
  # State styling is handled by the existing status-tag CSS component
  # (see app/assets/tailwind/components/status_tag.css) via data-status.
  #
  def search_result_locals(record, query)
    case record
    when Member then search_result_for_member(record, query)
    when Membership then search_result_for_membership(record, query)
    when Invoice then search_result_for_invoice(record, query)
    when Payment then search_result_for_payment(record, query)
    when Shop::Order then search_result_for_shop_order(record, query)
    when Shop::Product then search_result_for_shop_product(record, query)
    when ActivityParticipation then search_result_for_activity_participation(record, query)
    else
      raise ArgumentError, "No search result mapping for #{record.class.name}"
    end
  end

  private

  def search_result_for_member(member, query)
    parts = [ "##{member.id}" ]
    parts << highlight_search(member.emails, query) if member.emails.present?
    if member.city.present? || member.zip.present?
      location = highlight_search([ member.zip, member.city ].compact_blank.join("\u00A0"), query)
      parts << content_tag(:span, location, style: "white-space: nowrap")
    end

    {
      icon_name: "user",
      url: member_path(member),
      title: member.name,
      subtitle_parts: parts,
      state: member.state,
      state_label: t("states.member.#{member.state}")
    }
  end

  def search_result_for_membership(membership, query)
    parts = []
    parts << highlight_search(membership.member&.name, query)
    parts << safe_join([
      highlight_search(I18n.l(membership.started_on, format: :number), query),
      " – ",
      highlight_search(I18n.l(membership.ended_on, format: :number), query)
    ])

    {
      icon_name: "calendar-range",
      url: membership_path(membership),
      title: "#{Membership.model_name.human} ##{membership.id}",
      subtitle_parts: parts,
      state: membership.state,
      state_label: t("states.membership.#{membership.state}")
    }
  end

  def search_result_for_invoice(invoice, query)
    parts = []
    parts << highlight_search(invoice.member&.name, query)
    parts << highlight_search(cur(invoice.amount), query) if invoice.amount.present?
    parts << highlight_search(I18n.l(invoice.date, format: :number), query)

    {
      icon_name: "banknotes",
      url: invoice_path(invoice),
      title: "#{Invoice.model_name.human} ##{invoice.id}",
      subtitle_parts: parts,
      state: invoice.state,
      state_label: t("states.invoice.#{invoice.state}")
    }
  end

  def search_result_for_payment(payment, query)
    parts = []
    parts << highlight_search(payment.member&.name, query)
    parts << highlight_search(ccur(payment, :amount), query)
    parts << highlight_search(I18n.l(payment.date, format: :number), query)

    {
      icon_name: "banknotes",
      url: payment_path(payment),
      title: "#{Payment.model_name.human} ##{payment.id}",
      subtitle_parts: parts,
      state: payment.state,
      state_label: t("states.payment.#{payment.state}")
    }
  end

  def search_result_for_shop_order(order, query)
    parts = []
    parts << highlight_search(order.member&.name, query)
    parts << highlight_search(cur(order.amount), query)
    parts << highlight_search(I18n.l(order.delivery_date, format: :number), query) if order.delivery_date

    {
      icon_name: "shopping-basket",
      url: shop_order_path(order),
      title: "#{Shop::Order.model_name.human} ##{order.id}",
      subtitle_parts: parts,
      state: order.state,
      state_label: t("states.shop/order.#{order.state}")
    }
  end

  def search_result_for_shop_product(product, query)
    parts = []
    parts << highlight_search(product.producer.name, query) if product.producer_id?

    {
      icon_name: "shopping-basket",
      url: edit_shop_product_path(product),
      title: product.name,
      subtitle_parts: parts,
      state: product.state,
      state_label: t("states.shop/product.#{product.state}")
    }
  end

  def search_result_for_activity_participation(participation, query)
    parts = []
    parts << highlight_search(participation.member&.name, query)
    parts << highlight_search(I18n.l(participation.activity_date, format: :number), query) if participation.activity_date

    {
      icon_name: "handshake",
      url: activity_participation_path(participation),
      title: participation.activity.title,
      subtitle_parts: parts,
      state: participation.state,
      state_label: t("states.activity_participation.#{participation.state}")
    }
  end
end
