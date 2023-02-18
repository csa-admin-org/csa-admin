module FormsHelper
  def translated_input(form, attr, options = {})
    locales = Array(options.delete(:locale) || Current.acp.languages)
    input_html = options.delete(:input_html) || {}
    label_option = options.delete(:label)
    locales.each do |locale|
      klass = form.object.class.name.underscore.gsub('/', '_')
      label =
        label_option&.call(locale) ||
          label_with_language(
            form.object.class.human_attribute_name(attr.to_s.singularize),
            locale)

      value = form.object.send(attr)[locale]
      if value.respond_to?(:to_trix_html)
        value = value.to_trix_html
      end
      form.input "#{attr.to_s.singularize}_#{locale}".to_sym, {
        label: label,
        input_html: {
          class: "#{klass}_#{attr.to_s.singularize}",
          value: value
        }.merge(input_html)
      }.deep_merge(options)
    end
  end

  def language_input(form)
    if Current.acp.languages.many?
      form.input :language,
        collection: Current.acp.languages.map { |l| [t("languages.#{l}"), l] },
        prompt: true
    end
  end

  def countries_collection(codes = [])
    countries = ISO3166::Country.all
    countries.select! { |c| c.alpha2.in? codes } if codes.any?
    countries.map { |country|
      [country.translations[I18n.locale.to_s], country.alpha2]
    }.sort_by { |(name, code)| ActiveSupport::Inflector.transliterate name }
  end

  def form_modes_collection
    ACP::FORM_MODES.map { |mode| [t("form_modes.#{mode}"), mode] }
  end

  def label_with_language(txt, locale)
    if Current.acp.languages.many?
      txt += " (#{I18n.t("languages.#{locale}")})"
    end
    txt
  end
end
