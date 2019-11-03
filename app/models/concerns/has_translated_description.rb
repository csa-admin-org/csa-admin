module HasTranslatedDescription
  extend ActiveSupport::Concern

  included do
    I18n.available_locales.each do |locale|
      has_rich_text "description_#{locale}"
    end
  end

  def descriptions=(attrs = {})
    attrs.each do |locale, body|
      send("description_#{locale}=", body)
    end
  end

  def descriptions
    Current.acp.languages.map { |locale|
      [locale, send("description_#{locale}")]
    }.to_h
  end

  def description
    send("description_#{I18n.locale}").to_s
  end
end
