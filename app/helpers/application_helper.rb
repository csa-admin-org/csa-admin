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
          suppressions = EmailSuppression.outbound.where(email: email)
          if suppressions.any?
            arbre.s(email)
            suppressions.each do |suppression|
              arbre.status_tag suppression.reason.underscore
            end
            if suppressions.deletable.any?
              arbre.span do
                link_to(t('helpers.email_suppressions.destroy'), suppressions.first,
                  method: :delete,
                  class: 'button',
                  data: { confirm: t('helpers.email_suppressions.destroy_confirm') })
              end
            end
          else
            mail_to(email)
          end
        end
      end
    end
  end

  def display_phones_with_link(arbre, phones)
    return unless phones.present?

    arbre.ul do
      Array(phones).map do |phone|
        arbre.li do
          link_to(
            phone.phony_formatted,
            'tel:' + phone.phony_formatted(spaces: '', format: :international))
        end
      end
    end
  end

  def display_price_description(price, description)
    "#{cur(price)} #{"(#{description})" if price.positive?}"
  end

  def any_basket_complements?
    BasketComplement.any?
  end

  def fiscal_years_collection
    min_year = Delivery.minimum(:date)&.year || Date.today.year
    max_year = Delivery.maximum(:date)&.year || Date.today.year
    (min_year..max_year).map { |year|
      fy = Current.acp.fiscal_year_for(year)
      [fy.to_s, fy.year]
    }.reverse
  end

  def renewal_states_collection
    %i[
      renewal_enabled
      renewal_opened
      renewal_canceled
      renewed
    ].map { |state|
      [I18n.t("active_admin.status_tag.#{state}").capitalize, state]
    }
  end

  def deliveries_cycles_collection
    DeliveriesCycle.all.map { |cycle|
      [
        "#{cycle.name} (#{t('helpers.deliveries_count', count: cycle.deliveries_count)})",
        cycle.id
      ]
    }
  end

  def wdays_collection(novalue = nil)
    col = Array(0..6).rotate.map { |d| [I18n.t('date.day_names')[d].capitalize, d] }
    col = [[novalue, nil]] + col if novalue
    col
  end

  def months_collection
    Array(1..12).rotate(Current.fiscal_year.range.min.month - 1).map { |d|
      [I18n.t('date.month_names')[d].capitalize, d]
    }
  end

  def referer_filter_member_id
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig('q', 'member_id_eq')
  end

  def referer_filter_activity_id
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig('q', 'activity_id_eq')
  end

  def postmark_url(path = 'streams')
    server_id = Current.acp.credentials(:postmark, :server_id)
    "https://account.postmarkapp.com/servers/#{server_id}/#{path}"
  end

  def handbook_icon_link(*args)
    link_to(handbook_page_path(*args), title: I18n.t('layouts.footer.handbook')) do
      inline_svg_tag('admin/book-open.svg', size: '24')
    end
  end
end
