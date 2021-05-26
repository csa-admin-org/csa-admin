module TranslatedRichTexts
  extend ActiveSupport::Concern

  class_methods do
    def translated_rich_texts(*texts)
      texts.each do |text|
        Rails.application.config.i18n.available_locales.each do |locale|
          has_rich_text "#{text}_#{locale}"
        end

        plural = text.to_s.pluralize
        define_method("#{plural}=") { |attrs = {}|
          attrs.each do |locale, body|
            send("#{text}_#{locale}=", body)
          end
        }
        define_method(plural) {
          Current.acp.languages.map { |locale|
            [locale, send("#{text}_#{locale}")]
          }.to_h
        }
        define_method(text) {
          send("#{text}_#{I18n.locale}").to_s
        }
        define_method("#{text}_as_plain_text") {
          send("#{text}_#{I18n.locale}").to_plain_text
        }
        define_method("#{text}=") { |str|
          send("#{text}_#{I18n.locale}=", str)
        }
      end
    end
  end
end
