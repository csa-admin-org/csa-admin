module FormsHelper
  def translated_input(form, attr, **options)
    form.semantic_fields_for attr do |f|
      Current.acp.languages.each do |locale|
        f.input locale, {
          label: attribute_label(form.object.class, attr, locale),
          input_html: { value: form.object.send(attr)[locale] }
        }.merge(options)
      end
    end
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
