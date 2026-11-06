# frozen_string_literal: true

module TranslatedRichTexts
  extend ActiveSupport::Concern

  included do
    after_create :reuse_existing_translated_rich_texts
  end

  class_methods do
    def translated_rich_texts(*texts, required: false)
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
          Current.org.languages.map { |locale|
            [ locale, send("#{text}_#{locale}") ]
          }.to_h
        }
        define_method("all_#{plural}?") {
          Current.org.languages.all? { |locale|
            send("#{text}_#{locale}").to_plain_text.present?
          }
        }
        define_method("any_#{plural}?") {
          Current.org.languages.any? { |locale|
            send("#{text}_#{locale}").to_plain_text.present?
          }
        }
        define_method(text) {
          send("#{text}_#{I18n.locale}").to_s
        }
        define_method("#{text}?") {
          send("#{text}_as_plain_text").present?
        }
        define_method("#{text}_as_plain_text") {
          send("#{text}_#{I18n.locale}").to_plain_text
        }
        define_method("#{text}=") { |str|
          send("#{text}_#{I18n.locale}=", str)
        }

        if required
          validate_options = required.is_a?(Hash) ? required : {}
          required_condition = required if required.respond_to?(:call)
          Rails.application.config.i18n.available_locales.each do |locale|
            validates "#{text}_#{locale}".to_sym, presence: true, **validate_options, if: -> {
              locale.to_s.in?(Current.org.languages) &&
                (!required_condition || instance_exec(&required_condition))
            }
          end
        end
      end
    end
  end

  private

  # Demo reset deletes records with delete_all and restarts primary keys, so a
  # new row can reuse an id that still has a rich text. Autosave would insert a
  # second row and raise RecordNotUnique. Keep the existing row and let autosave
  # write the new body into it.
  def reuse_existing_translated_rich_texts
    self.class.rich_text_association_names.each do |name|
      association = association(name)
      next unless association.loaded?

      draft = association.target
      next unless draft&.new_record?

      existing = ActionText::RichText.find_by(record: self, name: draft.name)
      next unless existing

      existing.body = draft.body
      association.target = existing
    end
  end
end
