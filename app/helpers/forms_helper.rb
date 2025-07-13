# frozen_string_literal: true

module FormsHelper
  def translated_input(form, attr, options = {})
    locales = Array(options.delete(:locale) || Current.org.languages)
    input_html = options.delete(:input_html) || {}
    label_option = options.delete(:label)
    placeholder_option = options.delete(:placeholder)
    locales.each do |locale|
      klass = form.object.class.name.underscore.gsub("/", "_")
      label =
        if label_option == false
          false
        else
          label_option&.call(locale) ||
            label_with_language(
              form.object.class.human_attribute_name(attr.to_s.singularize),
              locale)
        end
      placeholder = if placeholder_option&.respond_to?(:call)
        placeholder_option.call(locale)
      else
        placeholder_option
      end

      value = form.object.send(attr)[locale]
      if value.respond_to?(:to_trix_html)
        value = value.to_trix_html
      end
      form.input "#{attr.to_s.singularize}_#{locale}".to_sym, {
        label: label,
        placeholder: placeholder,
        input_html: {
          class: "#{klass}_#{attr.to_s.singularize} #{"trix-content" if options[:as] == :action_text}",
          value: value
        }.merge(input_html)
      }.deep_merge(options)
    end
  end

  def language_input(form)
    if Current.org.languages.many?
      form.input :language,
        collection: Current.org.languages.map { |l| [ t("languages.#{l}"), l ] },
        prompt: true
    end
  end

  def countries_collection(codes = [])
    countries = ISO3166::Country.all
    countries.select! { |c| c.alpha2.in? codes } if codes.any?
    countries.map { |country|
      [ country.translations[I18n.locale.to_s], country.alpha2 ]
    }.sort_by { |(name, code)| ActiveSupport::Inflector.transliterate name }
  end

  def form_modes_collection
    Organization::INPUT_FORM_MODES.map { |mode| [ t("form_modes.#{mode}"), mode ] }
  end

  def label_with_language(txt, locale)
    if Current.org.languages.many?
      txt += " (#{I18n.t("languages.#{locale}")})"
    end
    txt
  end

  def member_order_priorities_collection
    [
      [ t("member_order.priorities.first"), 0 ],
      [ t("member_order.priorities.default"), 1 ],
      [ t("member_order.priorities.last"), 2 ]
    ]
  end

  def member_order_modes_collection(klass)
    klass::MEMBER_ORDER_MODES.map { |mode|
      [ t("member_order.modes.#{mode}"), mode ]
    }
  end
end
