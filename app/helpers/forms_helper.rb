module FormsHelper
  def translated_input(form, attr, **options)
    Current.acp.languages.each do |locale|
      form.input "#{attr.to_s.singularize}_#{locale}".to_sym, {
        label: attribute_label(form.object.class, attr, locale),
        input_html: {
          value: form.object.send(attr)[locale],
          name: "#{form.object.class.name.underscore}[#{attr}][#{locale}]"
        }
      }.deep_merge(**options)
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
