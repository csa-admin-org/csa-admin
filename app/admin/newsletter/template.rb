# frozen_string_literal: true

ActiveAdmin.register Newsletter::Template do
  menu false
  actions :all, except: [ :show ]

  breadcrumb do
    links = [ link_to(Newsletter.model_name.human(count: 2), newsletters_path) ]
    if params[:action] != "index"
      links << link_to(Newsletter::Template.model_name.human(count: 2), newsletter_templates_path)
    end
    links
  end

  includes :newsletters
  index download_links: false do
    column :title, sortable: true
    column :newsletters, ->(t) {
      link_to t.newsletters.count, newsletters_path(q: { template_id_eq: t.id })
    }, class: "text-right"
    actions do |template|
      link_to(new_newsletter_template_path(template_id: template.id), title: t(".duplicate")) do
        icon "document-duplicate", class: "size-5"
      end
    end
  end

  form data: {
    controller: "code-editor",
    code_editor_target: "form",
    code_editor_preview_path_value: "/newsletter_templates/preview.js"
  } do |f|
    newsletter_template = f.object
    f.inputs t(".details") do
      f.input :title
      translated_input(f, :contents,
        as: :text,
        hint: t("formtastic.hints.liquid_html"),
        input_html: {
          data: { mode: "liquid", code_editor_target: "editor" }
        })

      handbook_button(self, "newsletters", anchor: "templates")
    end
    div "data-controller" => "iframe", class: "flex  gap-5" do
      Current.org.languages.each do |locale|
        div class: "w-full" do
          title = t(".preview")
          title += " (#{t("languages.#{locale}")})" if Current.org.languages.many?
          f.inputs title do
            li class: "iframe-wrapper" do
              iframe(
                srcdoc: newsletter_template.mail_preview(locale),
                scrolling: "no",
                class: "mail_preview",
                id: "mail_preview_#{locale}",
                "data-iframe-target" => "iframe")
            end
            translated_input(f, :liquid_data_preview_yamls,
              locale: locale,
              as: :text,
              hint: t("formtastic.hints.liquid_data_preview"),
              input_html: {
                data: { mode: "yaml", code_editor_target: "editor" },
                name: "newsletter_template[liquid_data_preview_yamls][#{locale}]"
              })
          end
        end
      end
    end
    f.actions
  end

  permit_params(
    :title,
    *I18n.available_locales.map { |l| "content_#{l}" },
    liquid_data_preview_yamls: I18n.available_locales)

  collection_action :preview, method: :post do
    @newsletter_template = resource_class.new
    resource.assign_attributes(permitted_params[:newsletter_template])
    render "mail_templates/preview"
  end

  before_build do |resource|
    if template = Newsletter::Template.find_by(id: params[:template_id])
      resource.title = template.title + " (copy)"
      resource.contents = template.contents
    end
  end

  controller do
    skip_before_action :verify_authenticity_token, only: :preview
  end

  config.filters = false
  config.sort_order = "title_asc"
end
