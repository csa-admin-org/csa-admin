module ApplicationHelper
  def spaced(string, size: 3)
    string = string.to_s
    (size - string.length).times do
      string = "&emsp;#{string}"
    end
    string.html_safe
  end

  def text_format(text)
    simple_format(text) if text.present?
  end

  def display_emails_with_link(arbre, emails)
    return unless emails.present?

    arbre.ul do
      Array(emails).map do |email|
        arbre.li do
          display_email_with_link(arbre, email)
        end
      end
    end
  end

  def display_name_with_public_name(object)
    txt = object.display_name
    if object.public_name != txt
      txt += content_tag(:span, object.public_name, class: "subtitle")
    end
    txt.html_safe
  end

  def display_email_with_link(arbre, email)
    suppressions =
      EmailSuppression
        .active
        .where(email: email)
        .where.not(reason: "ManualSuppression")
    if suppressions.any?
      arbre.s(email)
      suppressions.each do |suppression|
        arbre.status_tag suppression.reason.underscore
        if suppression.unsuppressable?
          arbre.span do
            link_to(t("helpers.email_suppressions.destroy"), suppression,
              method: :delete,
              class: "button",
              data: { confirm: t("helpers.email_suppressions.destroy_confirm") })
          end
        end
      end
    else
      mail_to(email)
    end
  end

  def display_phones_with_link(arbre, phones)
    return unless phones.present?

    arbre.ul do
      Array(phones).map do |phone|
        arbre.li phone_link(phone)
      end
    end
  end

  def display_attachment(attachment)
    link_to(
      "#{attachment.filename} (#{number_to_human_size(attachment.byte_size)})",
      rails_blob_path(attachment, disposition: "attachment"))
  end

  def phone_link(phone)
    phone_to(
      phone.phony_formatted(spaces: "", format: :international),
      display_phone(phone))
  end

  def display_phone(phone)
    format =
      if PhonyRails.country_from_number(phone) == Current.acp.country_code
        :national
      else
        :international
      end
    phone.phony_formatted(format: format)
  end

  def display_price_description(price, description)
    txt = ""
    unless price.zero?
      txt += content_tag(:span, description, class: "details")
    end
    txt += content_tag(:span, cur(price, unit: false), class: "price")
    txt.html_safe
  end

  def any_basket_complements?
    BasketComplement.any?
  end

  def fiscal_years_collection
    min_year = Delivery.minimum(:date)&.year || Date.today.year
    max_year = Delivery.maximum(:date)&.year || Date.today.year
    (min_year..max_year).map { |year|
      fy = Current.acp.fiscal_year_for(year)
      [ fy.to_s, fy.year ]
    }.reverse
  end

  def renewal_states_collection
    Membership::RENEWAL_STATES.map { |state|
      [ I18n.t("active_admin.status_tag.#{state}").capitalize, state ]
    }
  end

  def delivery_cycles_collection
    DeliveryCycle.all.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id
      ]
    }
  end

  def display_objects(objects, limit: 5)
    return "–" if objects.empty?

    links = objects.first(limit).map { |o| auto_link(o) }
    if objects.size > limit
      links.join(", ").html_safe + ", ..."
    else
      links.to_sentence.html_safe
    end
  end

  def wdays_collection(novalue = nil)
    col = Array(0..6).rotate.map { |d| [ I18n.t("date.day_names")[d].capitalize, d ] }
    col = [ [ novalue, nil ] ] + col if novalue
    col
  end

  def months_collection
    Array(1..12).rotate(Current.fiscal_year.range.min.month - 1).map { |d|
      [ I18n.t("date.month_names")[d].capitalize, d ]
    }
  end

  def referer_filter(attr)
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig("q", "#{attr}_eq")
  end

  def postmark_url(path = "streams")
    server_id = Current.acp.credentials(:postmark, :server_id)
    "https://account.postmarkapp.com/servers/#{server_id}/#{path}"
  end

  def handbook_icon_link(*args)
    link_to(handbook_page_path(*args), title: I18n.t("layouts.footer.handbook"), class: "color-light") do
      inline_svg_tag("admin/book-open.svg", size: "24")
    end
  end
end
