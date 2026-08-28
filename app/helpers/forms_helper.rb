# frozen_string_literal: true

module FormsHelper
  def newsletter_block_content_hint(block)
    if block.public_content? && block.public_feed?
      content_tag(:span, class: "newsletter-public-hint") do
        safe_join([
          content_tag(:span,
            t("formtastic.hints.newsletter/block.public_content_html").html_safe),
          tooltip(
            "newsletter-block-#{block.template_id}-#{block.block_id}-public",
            t("active_admin.resource.form.newsletter.public_content_tooltip"),
            trigger_class: "cluster is-snug is-nowrap is-soft") do
            safe_join([
              icon("eye", class: "icon-4"),
              content_tag(:span,
                t("active_admin.resource.form.newsletter.public_content"),
                class: "font-medium")
            ])
          end
        ])
      end
    else
      t("formtastic.hints.liquid_html").html_safe
    end
  end

  def mail_preview_inputs(arbre, form, record)
    param_key = record.class.model_name.param_key
    arbre.div "data-controller" => "iframe", class: "mail-preview-grid" do
      Current.org.languages.each do |locale|
        arbre.div class: "mail-preview-pane" do
          title = I18n.t("active_admin.resource.form.preview")
          title += " (#{I18n.t("languages.#{locale}")})" if Current.org.languages.many?
          form.inputs title, icon: "eye" do
            arbre.li class: "iframe-wrapper" do
              arbre.iframe(
                srcdoc: record.mail_preview(locale),
                scrolling: "no",
                class: "mail_preview",
                id: "mail_preview_#{locale}",
                "data-iframe-target" => "iframe")
            end
            translated_input(form, :liquid_data_preview_yamls,
              locale: locale,
              as: :text,
              hint: I18n.t("formtastic.hints.liquid_data_preview_html").html_safe,
              input_html: {
                data: { mode: "yaml", code_editor_target: "editor", max_height: "24em" },
                name: "#{param_key}[liquid_data_preview_yamls][#{locale}]"
              })
          end
        end
      end
    end
  end

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
      class: "trix-word-count-warning is-hidden",
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
