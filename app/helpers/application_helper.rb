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

  def display_emails_with_link(emails)
    Array(emails).map { |email| mail_to(email) }.join(', ').html_safe
  end

  def display_phones_with_link(phones)
    Array(phones).map { |phone|
      link_to(
        phone.phony_formatted,
        'tel:' + phone.phony_formatted(spaces: '', format: :international))
    }.join(', ').html_safe
  end

  def display_price_description(price, description)
    "#{cur(price)} #{"(#{description})" if price.positive?}"
  end

  def any_basket_complements?
    BasketComplement.any?
  end

  def seasons_collection
    ACP.seasons.map { |season| [I18n.t("season.#{season}"), season] }
  end

  def seasons_filter_collection
    filters = ACP.seasons + ACP.seasons.map { |s| s + '_only' }
    filters.map { |season| [I18n.t("season.#{season}"), season] }
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

  def wdays_collection
    Array(0..6).rotate.map { |d| [I18n.t('date.day_names')[d].capitalize, d] }
  end

  def referer_filter_member_id
    return unless request&.referer

    query = URI(request.referer).query
    Rack::Utils.parse_nested_query(query).dig('q', 'member_id_eq')
  end

  def postmark_url(path = 'streams')
    server_id = Current.acp.credentials(:postmark, :server_id)
    "https://account.postmarkapp.com/servers/#{server_id}/#{path}"
  end
end
