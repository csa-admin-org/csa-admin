module FormsHelper
  def translated_input(form, attr, options = {})
    locales = Array(options.delete(:locale) || Current.acp.languages)
    locales.each do |locale|
      klass = form.object.class.name.underscore.gsub('/', '_')
      form.input "#{attr.to_s.singularize}_#{locale}".to_sym, {
        label: attribute_label(form.object.class, attr, locale),
        input_html: {
          class: "#{klass}_#{attr.to_s.singularize}",
          value: form.object.send(attr)[locale],
          name: "#{klass}[#{attr}][#{locale}]"
        }
      }.deep_merge(options)
    end
  end

  def countries_collection(codes = [])
    countries = ISO3166::Country.all
    countries.select! { |c| c.alpha2.in? codes } if codes.any?
    countries.map { |country|
      [country.translations[I18n.locale.to_s], country.alpha2]
    }.sort_by { |(name, code)| ActiveSupport::Inflector.transliterate name }
  end

  private

  def attribute_label(model_class, attr, locale)
    txt = model_class.human_attribute_name(attr.to_s.singularize)
    if Current.acp.languages.many?
      txt += " (#{I18n.t("languages.#{locale}")})"
    end
    txt
  end
end
