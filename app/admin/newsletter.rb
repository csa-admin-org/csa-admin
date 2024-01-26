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

  scope :all
  scope :draft, default: true
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

  show title: ->(n) { n.subject.truncate(40) } do |newsletter|
    columns do
      column do
        attributes_table do
          row(:id)
          row(:subject)
          row(:audience) { newsletter.audience_name }
          row(Member.model_name.human(count: 2)) {
            "#{newsletter.members_count} (#{newsletter.emails.size} #{t('.subscribed_emails')})"
          }
          row(:from) { newsletter.from || Current.acp.email_default_from.html_safe }
          row(:attachments) { newsletter.attachments.map { |a| display_attachment(a.file) } }
          row(:template)
          row(:status) {
            if newsletter.ongoing_delivery?
              status_tag t(".ongoing_delivery")
            else
              status_tag newsletter.sent_at? ? :sent : :draft
            end
          }
          if newsletter.sent_at? && !newsletter.ongoing_delivery?
            row(:sent_at) { I18n.l(newsletter.sent_at, format: :medium) }
            row(:sent_by)
          end
          row(:created_at) { I18n.l(newsletter.created_at, format: :medium) }
          row(:updated_at) { I18n.l(newsletter.updated_at, format: :medium) }
        end
      end
      column do
        panel t(".suppressed_emails", count: newsletter.suppressed_emails.size), data: { controller: "show-all" } do
          if newsletter.suppressed_emails.any?
            members = newsletter.all_members
            active_suppressions = EmailSuppression.active.where(email: newsletter.suppressed_emails)
            newsletter.suppressed_emails.sort_by! { |email|
              active_suppressions.find { |s| s.email == email }&.created_at || 10.years.ago
            }&.reverse!
            table_for(newsletter.suppressed_emails, class: "partially-hidden", data: { "show-all-target" => "elements" }) do
              column(:email) { |email|
                member = members.find { |m| m.emails_array.include?(email) }
                if member
                  link_to email, member
                else
                  content_tag :strike, email
                end
              }
              column(t(".active_suppression_reasons")) { |email|
                member = members.find { |m| m.emails_array.include?(email) }
                reasons = active_suppressions.select { |s| s.email == email }.map(&:reason).uniq
                if member
                  if reasons.any?
                    content_tag :div do
                      reasons.map { |r| status_tag(r.underscore) }
                    end
                  else
                    status_tag(:active)
                  end
                else
                  status_tag(:deleted)
                end
              }
            end
            if newsletter.suppressed_emails.size > 6
              em link_to(t(".show_all")), class: "show_more", data: { action: "click->show-all#showAll" }
            end
            para class: "bottom-text" do
              em do
                if newsletter.sent?
                  t(".suppressed_emails_sent_description")
                else
                  t(".suppressed_emails_description")
                end
              end
            end
          else
            em t(".none")
          end
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

  action_item :send_email, class: "left-margin", only: :show, if: -> { authorized?(:send_email, resource) } do
    button_to t(".send_email"), send_email_newsletter_path(resource),
      form: { data: { controller: "disable", disable_with_value: t("formtastic.processing") } },
      data: { confirm: t(".newsletter.confirm", members_count: resource.members_count) }
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
