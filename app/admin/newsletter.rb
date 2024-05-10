ActiveAdmin.register Newsletter do
  menu priority: 99, label: -> {
    inline_svg_tag("admin/envelope.svg", size: "20", title: Newsletter.model_name.human)
  }

  filter :id
  filter :subject_cont,
    label: -> { Newsletter.human_attribute_name(:subject) },
    as: :string
  filter :template
  filter :members_segmemt
  filter :sent_at

  scope :all, default: true
  scope :draft
  scope :sent

  action_item :segments, only: :index, if: -> { authorized?(:create, Newsletter::Segment) } do
    link_to Newsletter.human_attribute_name(:audience), newsletter_segments_path
  end
  action_item :templates, only: :index do
    link_to Newsletter::Template.model_name.human(count: 2), newsletter_templates_path
  end

  index download_links: false do
    column :id, ->(n) { link_to n.id, n }
    column :subject, ->(n) { link_to n.subject, n }
    column :audience, ->(n) { n.audience_name }
    column :sent_at, ->(n) {
      if n.sent_at?
        I18n.l(n.sent_at, format: :medium)
      else
        status_tag :draft
      end
    }
    actions defaults: true, class: "col-actions-4" do |newsletter|
      link_to(t(".duplicate"), new_newsletter_path(newsletter_id: newsletter.id), class: "duplicate_link", title: t(".duplicate"))
    end
  end

  sidebar_handbook_link("newsletters")

  show do |newsletter|
    columns do
      column do
        panel "#{Newsletter.human_attribute_name(:audience)} – #{newsletter.audience_name}" do
          ul class: "counts" do
            if newsletter.sent?
              li do
                count = newsletter.members.count
                counter_tag(Member.model_name.human(count: count), count)
              end
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
              li do
                count = newsletter.deliveries.ignored.count
                link_to newsletter_deliveries_path(scope: :ignored, q: { newsletter_id_eq: newsletter.id }) do
                  counter_tag(t(".suppressed_emails", count: count), count)
                end
              end
            else
              li do
                count = newsletter.audience_segment.members.count
                counter_tag(Member.model_name.human(count: count), count)
              end
              li do
                count = newsletter.audience_segment.emails.size
                counter_tag(t(".emails", count: count), count)
              end
              li do
                  count = newsletter.audience_segment.suppressed_emails.size
                  link_to('#suppressed-emails', data: { turbolinks: false }) do
                    counter_tag(t(".suppressed_emails", count: count), count)
                  end
              end
            end
          end
        end

      end
      column do
        attributes_table do
          row(:status) {
            if newsletter.pending_delivery?
              status_tag t(".pending_delivery"), class: 'processing'
            elsif newsletter.sent_at?
              status_tag :sent, title: [
                "#{Newsletter.human_attribute_name(:sent_at)}: #{I18n.l(newsletter.sent_at, format: :medium)}",
                "#{Newsletter.human_attribute_name(:sent_by)}: #{newsletter.sent_by&.name}"
              ].join(" / ").html_safe
            else
              status_tag :draft,
                title: "#{Newsletter.human_attribute_name(:updated_at)}: #{I18n.l(newsletter.updated_at, format: :medium)}"
            end
          }
          row(:attachments) { newsletter.attachments.map { |a| display_attachment(a.file) } }
        end
      end
    end
    columns "data-controller" => "iframe-resize" do
      Current.acp.languages.each do |locale|
        column do
          title = t(".preview")
          title += " (#{t("languages.#{locale}")})" if Current.acp.languages.many?
          panel title do
            iframe(
              srcdoc: newsletter.mail_preview(locale),
              scrolling: "no",
              class: "mail_preview",
              id: "mail_preview_#{locale}",
              "data-iframe-resize-target" => "iframe")
          end
        end
      end
    end
    unless newsletter.sent?
      columns id: "suppressed-emails" do
        column do
          suppressed_emails = newsletter.audience_segment.suppressed_emails
          panel "#{t(".suppressed_emails", count: suppressed_emails.size)} (#{suppressed_emails.size})", data: { controller: "show-all" } do
            if suppressed_emails.any?
              members = newsletter.audience_segment.members
              active_suppressions = EmailSuppression.active.where(email: suppressed_emails)
              suppressed_emails.sort_by! { |email|
                active_suppressions.find { |s| s.email == email }&.created_at || 10.years.ago
              }&.reverse!
              suppressions = suppressed_emails.map { |email|
                OpenStruct.new(
                  member: members.find { |m| m.emails_array.include?(email) },
                  email: email,
                  reasons: active_suppressions.select { |s| s.email == email }.map(&:reason).uniq)
              }
              table_for(suppressions, class: "partially-hidden", data: { "show-all-target" => "elements" }) do
                column(Member.model_name.human) { |s| auto_link s.member }
                column(Newsletter::Delivery.human_attribute_name(:email)) { |s| s.email }
                column(Newsletter::Delivery.human_attribute_name(:state), class: 'align-right') { |s|
                  if s.reasons.any?
                    content_tag :div do
                      s.reasons.map { |r| status_tag(r.underscore) }
                    end
                  else
                    status_tag(:active)
                  end
                }
              end
              if suppressed_emails.size > 10
                em link_to(t(".show_all")), class: "show_more", data: { action: "click->show-all#showAll" }
              end
              para class: "bottom-text" do
                em t(".suppressed_emails_description")
              end
            else
              em t(".none")
            end
          end
        end
      end
    end
  end

  form data: {
    controller: "code-editor form-select-hidder auto-save",
    code_editor_target: "form",
    code_editor_preview_path_value: "/newsletters/preview.js",
    auto_save_target: "form",
    action: "change->auto-save#saveToLocalStorage trix-change->auto-save#saveToLocalStorage submit->auto-save#clearLocalStorage"
  } do |f|
    newsletter = f.object
    div class: "form-warning", data: { "auto-save-target" => "warningMessage" } do
      span t("newsletters.auto_save_recovered")
    end
    f.inputs t(".details") do
      f.input :id, as: :hidden
      translated_input(f, :subjects,
        hint: t("formtastic.hints.liquid").html_safe,
        input_html: {
          data: { action: "code-editor#updatePreview" }
        })
      f.input :audience, collection: newsletter_audience_collection, prompt: true
      errors_on(self, f, :attachments)

      f.input :from,
        as: :string,
        placeholder: Current.acp.email_default_from.html_safe,
        hint: t("formtastic.hints.newsletter.from_html", hostname: Current.acp.email_hostname)

      f.has_many :attachments, allow_destroy: true do |a|
        if a.object.persisted?
          content_tag :span, display_attachment(a.object.file), class: "filename"
        else
          a.input :file, as: :file
        end
      end
    end

    f.inputs t(".content") do
      f.input :template,
        prompt: true,
        include_blank: false,
        input_html: {
          data: { action: "form-select-hidder#toggle code-editor#updatePreview" }
        }

      errors_on(self, f, :blocks)
      f.semantic_fields_for :blocks do |b|
        b.input :id, as: :hidden
        b.input :block_id, as: :hidden
        b.input :template_id, as: :hidden
        translated_input(b, :contents,
          as: :action_text,
          label: ->(locale) {
            b.object.titles[locale] ||
              label_with_language(b.object.block_id.titleize, locale)
          },
          hint: t("formtastic.hints.liquid").html_safe,
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

      translated_input(f, :signatures,
        as: :text,
        placeholder: ->(locale) { Current.acp.email_signatures[locale]&.html_safe },
        input_html: {
          rows: 3,
          data: { action: "code-editor#updatePreview" }
        })
    end
    columns "data-controller" => "iframe-resize" do
      Current.acp.languages.each do |locale|
        column do
          title = t(".preview")
          title += " (#{t("languages.#{locale}")})" if Current.acp.languages.many?
          f.inputs title do
            div class: "iframe-wrapper" do
              iframe(
                srcdoc: newsletter.mail_preview(locale),
                scrolling: "no",
                class: "mail_preview",
                id: "mail_preview_#{locale}",
                "data-iframe-resize-target" => "iframe")
            end
            translated_input(f, :liquid_data_preview_yamls,
              locale: locale,
              as: :text,
              hint: t("formtastic.hints.liquid_data_preview"),
              wrapper_html: { class: "ace-editor" },
              input_html: {
                class: "ace-editor",
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
    f.actions do
      action(:submit, label: t(".submit_newsletter"))
      cancel_link
    end
  end

  permit_params(
    :from,
    :audience,
    :newsletter_template_id,
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
    link_to(t(".duplicate"), new_newsletter_path(newsletter_id: resource.id), class: "duplicate_link")
  end

  action_item :deliveries, only: :show, if: -> { resource.sent? } do
    link_to(
      Newsletter::Delivery.model_name.human(count: 2),
      newsletter_deliveries_path(scope: :all, q: { newsletter_id_eq: newsletter.id }))
  end

  action_item :send_email, class: "left-margin", only: :show, if: -> { authorized?(:send_email, resource) } do
    button_to t(".send_email"), send_email_newsletter_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      data: { confirm: t(".newsletter.confirm", members_count: resource.audience_segment.members.count) }
  end

  member_action :send_email, method: :post do
    resource.send!
    redirect_to resource_path, notice: t(".flash.notice")
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
      params[:order] ||= "sent_at_desc" if params[:scope].in?(%w[all sent])
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
      super resource, [ attrs ]
    end
  end
end
