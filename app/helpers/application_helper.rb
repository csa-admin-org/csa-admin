# frozen_string_literal: true

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

  def csa_admin_website_url
    path =
      case I18n.locale
      when :fr, :it then "/acp"
      when :de then "/solawi"
      end
    "https://csa-admin.org#{path}"
  end

  def display_emails_with_link(arbre, emails)
    return unless emails.present?

    arbre.ul class: "flex flex-wrap gap-1" do
      Array(emails).map do |email|
        arbre.li class: "flex flex-wrap gap-1" do
          display_email_with_link(arbre, email)
        end
      end
    end
  end

  def display_name_with_public_name(object)
    txt = object.display_name
    if object.public_name != txt
      txt += content_tag(:span, object.public_name, class: "block text-sm text-gray-500")
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
              class: "btn btn-xs",
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
      if PhonyRails.country_from_number(phone) == Current.org.country_code
        :national
      else
        :international
      end
    phone.phony_formatted(format: format)
  end

  def display_price_description(price, description)
    txt = ""
    unless price.zero?
      txt += content_tag(:span, description, class: "text-sm text-gray-500")
    end
    txt += content_tag(:span, cur(price, unit: false), class: "inline-block w-20")
    txt.html_safe
  end

  def any_basket_complements?
    BasketComplement.kept.any?
  end

  def fiscal_years_collection
    Current.org.fiscal_years.map { |fy|
      [ fy.to_s, fy.year ]
    }.reverse
  end

  def renewal_states_collection
    Membership::Renewal::STATES.map { |state|
      [ I18n.t("active_admin.status_tag.#{state}").capitalize, state ]
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

  def months_collection(fiscal_year_order: false)
    months = Array(1..12)
    if fiscal_year_order
      months = months.rotate(Current.fiscal_year.range.min.month - 1)
    end
    months.map { |d|
      [ I18n.t("date.month_names")[d].capitalize, d ]
    }
  end

  def themes_collection
    HasTheme::THEMES.map { |theme|
      icon_name = HasTheme::THEME_ICONS.fetch(theme)
      translation_key = theme == "system" ? "system_auto" : theme
      label = t("themes.#{translation_key}")
      [
        content_tag(:span, class: "inline-flex items-center gap-2") {
          icon(icon_name, class: "size-4") +
          content_tag(:span, label)
        },
        theme
      ]
    }
  end

  def referer_filter(attr)
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig("q", "#{attr}_eq")
  end

  def handbook_icon_link(*args)
    link_to handbook_page_path(*args), title: I18n.t("active_admin.site_footer.handbook") do
      icon "book-open", class: "size-6"
    end
  end
end
