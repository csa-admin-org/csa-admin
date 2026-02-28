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
          label_option&.call(locale)
            || label_with_language(
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

  def trix_word_count_wrapper(arbre, threshold:, handbook_page: :registration, handbook_anchor: "text-styling", &block)
    path = handbook_page_path(handbook_page, anchor: handbook_anchor)
    warning_html = I18n.t(
      "active_admin.resource.form.word_count_warning_html",
      count: '<b data-trix-word-count-target="count">0</b>',
      handbook_path: path
    )
    warning_div = content_tag(:div,
      warning_html.html_safe,
      class: "mt-2 rounded-md bg-orange-50 border border-orange-300 px-3 py-2 text-xs text-orange-800 " \
             "dark:bg-orange-900/30 dark:border-orange-700 dark:text-orange-400",
      data: { trix_word_count_target: "warning" })

    arbre.div data: {
      controller: "trix-word-count",
      trix_word_count_threshold_value: threshold
    } do
      arbre.text_node "<template data-trix-word-count-target=\"template\">#{warning_div}</template>".html_safe
      block.call
    end
  end
end
