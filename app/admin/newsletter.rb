# frozen_string_literal: true

ActiveAdmin.register Newsletter do
  menu parent: :email, priority: 1

  filter :id
  filter :subject_cont,
    label: -> { Newsletter.human_attribute_name(:subject) },
    as: :string
  filter :template
  filter :members_segmemt
  filter :sent_at

  scope :all, default: true
  scope :draft
  scope :scheduled
  scope :sent

  action_item :segments, only: :index, if: -> { authorized?(:create, Newsletter::Segment) } do
    link_to Newsletter.human_attribute_name(:audience), newsletter_segments_path, class: "action-item-button"
  end
  action_item :templates, only: :index do
    link_to Newsletter::Template.model_name.human(count: 2), newsletter_templates_path, class: "action-item-button"
  end

  index download_links: false do
    column :id, ->(n) { link_to n.id, n }
    column :subject, ->(n) { link_to n.subject, n }
    column :audience, ->(n) { n.audience_name }
    column :sent_at, ->(n) {
      span class: "whitespace-nowrap" do
        if n.sent?
          I18n.l(n.sent_at.to_date, format: :short)
        elsif n.scheduled?
          span class: "status-tag", data: { status: "scheduled" } do
            span { icon("clock", class: "size-3 me-1.5") }
            span { l(n.scheduled_at.to_date, format: :short) }
          end
        else
          status_tag :draft
        end
      end
    }, class: "text-right"
    actions do |newsletter|
      link_to new_newsletter_path(newsletter_id: newsletter.id), title: t(".duplicate") do
        icon "document-duplicate", class: "size-5"
      end
    end
  end

  sidebar_handbook_link("newsletters")

  show do |newsletter|
    columns do
      column "data-controller" => "iframe" do
        Current.org.languages.each do |locale|
          title = t(".preview")
          title += " (#{t("languages.#{locale}")})" if Current.org.languages.many?
          panel title do
            div class: "iframe-wrapper" do
              iframe(
                srcdoc: newsletter.mail_preview(locale),
                scrolling: "no",
                class: "mail_preview",
                id: "mail_preview_#{locale}",
                "data-iframe-target" => "iframe")
            end
          end
        end
      end
      column do
        if newsletter.scheduled?
          panel nil, class: "m-0 p-0 bg-orange-200 shadow-xs" do
            div class: "flex items-center text-orange-700 gap-2" do
              span(class: "ms-0.5") { icon("calendar-clock", class: "size-6") }
              span(class: "grow") { t(".newsletter_scheduled_at_html", on: l(newsletter.scheduled_at.to_date, format: :short)) }
              if authorized?(:unschedule, newsletter)
                span {
                  button_to unschedule_newsletter_path(newsletter), method: :put, class: "m-0 p-0 text-orange-300 hover:text-orange-500 cursor-pointer", form: { class: "flex items-center" }, data: { confirm: t(".confirm") } do
                    icon("x-circle", class: "size-6")
                  end
                }
              end
            end
          end
        end
        panel "#{Newsletter.human_attribute_name(:audience)} – #{newsletter.audience_name}".html_safe do
          ul class: "counts" do
            li do
              count = newsletter.members.count
              link_to newsletter_deliveries_path(scope: :all, q: { newsletter_id_eq: newsletter.id }) do
                counter_tag(Member.model_name.human(count: count), count)
              end
            end
            if newsletter.sent?
              li do
                count = newsletter.deliveries.delivered.count
                link_to newsletter_deliveries_path(scope: :delivered, q: { newsletter_id_eq: newsletter.id }) do
                  counter_tag(t(".delivered_emails", count: count), count)
                end
              end
              li do
                count = newsletter.deliveries.bounced.count
                link_to newsletter_deliveries_path(scope: :bounced, q: { newsletter_id_eq: newsletter.id }) do
                  counter_tag(t(".bounced_emails", count: count), count)
                end
              end
            else
              li do
                count = newsletter.deliveries.draft.count
                link_to newsletter_deliveries_path(scope: :draft, q: { newsletter_id_eq: newsletter.id }) do
                  counter_tag(t(".emails", count: count), count)
                end
              end
            end
            li do
              count = newsletter.deliveries.ignored.count
              link_to newsletter_deliveries_path(scope: :ignored, q: { newsletter_id_eq: newsletter.id }) do
                counter_tag(t(".suppressed_emails", count: count), count)
              end
            end
          end
        end
        panel t(".details") do
          attributes_table do
            case newsletter.state
            when "sent", "processing"
              row(:sent_at) { I18n.l(newsletter.sent_at, format: :medium) }
              row(:sent_by) { newsletter.sent_by&.name }
            when "draft", "scheduled"
              row(:updated_at) { I18n.l(newsletter.updated_at, format: :medium) }
            end
          end
        end
        render "active_admin/attachments/panel", attachments: newsletter.attachments

        if newsletter.sent?
          panel t(".missing_deliveries") do
            if newsletter.show_missing_delivery_emails?
              div do
                ul class: "ms-6 list-disc list-outside space-y-2" do
                  newsletter.missing_delivery_emails.each do |email|
                    member = Member.find_by_email(email)
                    li do
                      span { mail_to email }
                      span { "(#{auto_link(member)})".html_safe }
                      if authorized?(:send_single_email, resource)
                        span {
                          button_to t(".send_email"), send_single_email_newsletter_path(resource),
                            params: { email: email },
                            class: "action-item-button secondary small",
                            form: { class: "inline ms-2", data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
                            data: { confirm: t(".confirm") }
                        }
                      end
                    end
                  end
                end
              end
              div class: "mt-6 px-2" do
                para t(".missing_deliveries_description"), class: "italic text-sm text-gray-400 dark:text-gray-600"
              end
            elsif newsletter.missing_delivery_emails_allowed?
              para t(".missing_deliveries_no_emails"), class: "missing-data"
            else
              para t(".missing_deliveries_no_more_allowed"), class: "missing-data"
            end
          end
        end
      end
    end
  end

  form data: {
    turbo: false,
    controller: "code-editor form-select-hidder auto-save",
    code_editor_target: "form",
    code_editor_preview_path_value: "/newsletters/preview.js",
    auto_save_target: "form",
    action: "change->auto-save#saveToLocalStorage trix-change->auto-save#saveToLocalStorage submit->auto-save#clearLocalStorage"
  } do |f|
    newsletter = f.object
    div class: "hidden text-base text-center mb-2 text-orange-700 dark:text-orange-400", data: { "auto-save-target" => "warningMessage" } do
      t("newsletters.auto_save_recovered")
    end
    f.inputs t(".details") do
      f.input :id, as: :hidden
      translated_input(f, :subjects,
        hint: t("formtastic.hints.liquid_html"),
        input_html: {
          data: { action: "code-editor#updatePreview" }
        })
      f.input :audience, collection: newsletter_audience_collection, prompt: true

      f.input :from,
        as: :string,
        placeholder: Current.org.email_default_from.html_safe,
        hint: t("formtastic.hints.newsletter.from_html", domain: Tenant.domain)

      f.input :scheduled_at, as: :date_picker, input_html: { min: Date.tomorrow }
    end

    render partial: "active_admin/attachments/form", locals: { f: f }

    f.inputs t(".content") do
      f.input :template,
        prompt: true,
        include_blank: false,
        input_html: {
          data: { action: "form-select-hidder#toggle code-editor#updatePreview" }
        }

      f.semantic_fields_for :blocks do |b|
        b.object.validate
        b.input :id, as: :hidden
        b.input :block_id, as: :hidden
        b.input :template_id, as: :hidden
        translated_input(b, :contents,
          as: :action_text,
          label: ->(locale) {
            label = b.object.titles[locale] || b.object.block_id.titleize
            label_with_language(label, locale)
          },
          hint: t("formtastic.hints.liquid_html"),
          wrapper_html: {
            data: {
              form_select_hidder_target: "element",
              element_id: b.object.template_id
            },
            style: ("display: none" unless b.object.template_id == f.object.template.id)
          },
          input_html: {
            data: { action: "trix-change->code-editor#updatePreview" }
          })
      end
      f.semantic_errors :blocks

      translated_input(f, :signatures,
        as: :text,
        placeholder: ->(locale) { Current.org.email_signatures[locale]&.html_safe },
        input_html: {
          rows: 3,
          data: { action: "code-editor#updatePreview" }
        })
    end
    div "data-controller" => "iframe", class: "flex  gap-5" do
      Current.org.languages.each do |locale|
        div class: "w-full" do
          title = t(".preview")
          title += " (#{t("languages.#{locale}")})" if Current.org.languages.many?
          f.inputs title do
            li class: "iframe-wrapper" do
              iframe(
                srcdoc: newsletter.mail_preview(locale),
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
                data: {
                  mode: "yaml",
                  code_editor_target: "editor"
                },
                name: "newsletter[liquid_data_preview_yamls][#{locale}]"
              })
          end
        end
      end
    end
    f.actions
  end

  permit_params(
    :from,
    :audience,
    :newsletter_template_id,
    :scheduled_at,
    *I18n.available_locales.map { |l| "subject_#{l}" },
    *I18n.available_locales.map { |l| "signature_#{l}" },
    liquid_data_preview_yamls: I18n.available_locales,
    attachments_attributes: [ :id, :file, :_destroy ],
    blocks_attributes: [
      :id,
      :block_id,
      :template_id,
      *I18n.available_locales.map { |l| "content_#{l}" }
    ])

  collection_action :preview, method: :post do
    @newsletter = resource_class.new
    assign_attributes(resource, permitted_params[:newsletter])
    render "mail_templates/preview"
  end

  action_item :duplicate, only: :show, if: -> { authorized?(:create, resource) } do
    link_to(t(".duplicate"), new_newsletter_path(newsletter_id: resource.id), class: "action-item-button")
  end

  action_item :deliveries, only: :show do
    link_to(
      Newsletter::Delivery.model_name.human(count: 2),
      newsletter_deliveries_path(scope: :all, q: { newsletter_id_eq: resource.id }),
      class: "action-item-button")
  end

  action_item :deliveries, only: :index do
    link_to(
      Newsletter::Delivery.model_name.human(count: 2),
      newsletter_deliveries_path(scope: :all),
      class: "action-item-button")
  end

  action_item :send_email, class: "left-margin", only: :show, if: -> { authorized?(:send_email, resource) } do
    button_to t(".send_email"), send_email_newsletter_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      data: { confirm: t(".newsletter.confirm", members_count: resource.audience_segment.members.count) },
      class: "action-item-button"
  end

  member_action :unschedule, method: :put do
    resource.unschedule!
    redirect_to resource_path
  end

  member_action :send_email, method: :post do
    resource.send!
    redirect_to resource_path, notice: t(".flash.notice")
  end

  member_action :send_single_email, method: :post do
    resource.deliver!(params.require(:email))
    redirect_to resource_path, notice: t("newsletters.send_email.flash.notice")
  end

  order_by(:sent_at) do |order_clause|
    [
      order_clause.to_sql,
      "NULLS #{order_clause.order == "desc" ? "FIRST" : "LAST"}",
      ", scheduled_at #{order_clause.order}"
    ].join(" ")
  end

  controller do
    skip_before_action :verify_authenticity_token, only: :preview

    before_build do |resource|
      if newsletter = Newsletter.find_by(id: params[:newsletter_id])
        resource.subjects = newsletter.subjects
        resource.audience = newsletter.audience
        resource.template = newsletter.template
        resource.blocks = newsletter.blocks.map { |b| b.id = nil; b }
      else
        resource.template ||= Newsletter.last&.template || Newsletter::Template.first
      end
    end

    def apply_sorting(chain)
      params[:order] ||= "sent_at_desc" if params[:scope].in?([ nil, "all", "sent" ])
      super
    end

    def assign_attributes(resource, attributes)
      attrs = Array(attributes).first
      template_id = attrs[:newsletter_template_id]

      if attrs[:blocks_attributes]
        if params[:action] == "preview"
          attrs[:blocks_attributes].select! { |_, v| v[:template_id] == template_id }
          attrs[:blocks_attributes].each { |_, v| v.delete(:id) }
        else
          attrs[:blocks_attributes].each do |_, v|
            unless v[:template_id] == template_id
              v[:_destroy] = true
            end
          end
        end
      end

      if params[:action] == "preview"
        attrs.delete(:attachments_attributes)
      end

      super resource, [ attrs ]
    end
  end
end
