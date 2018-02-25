module ApplicationHelper
  def spaced(string, size: 3)
    string = string.to_s
    (size - string.length).times do
      string = "&emsp;#{string}"
    end
    string.html_safe
  end

  def gribouille_content(html)
    html.sub(/(<br>)+(<\/\w*>)*\z/) { |match| p match.gsub(/<br>/, '') }
  end

  def display_emails(emails)
    Array(emails).map { |email| mail_to(email) }.join(', ').html_safe
  end

  def display_phones(phones)
    Array(phones).map { |phone|
      link_to(
        phone.phony_formatted,
        "tel:" + phone.phony_formatted(spaces: '', format: :international))
    }.join(', ').html_safe
  end

  def display_basket_complement_names(complements)
    names = Array(complements).compact.map(&:name)
    if names.present?
      names.to_sentence
    else
      content_tag :em, 'Aucun'
    end
  end

  def display_price_description(price, description)
    "#{number_to_currency(price)} #{"(#{description})" if price.positive?}"
  end

  def seasons_collection
    ACP.seasons.map { |season| [I18n.t("season.#{season}"), season] }
  end
end
