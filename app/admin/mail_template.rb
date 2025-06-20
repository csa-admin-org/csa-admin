# frozen_string_literal: true

ActiveAdmin.register MailTemplate do
  menu parent: :email, priority: 2
  actions :index, :show, :edit, :update

  breadcrumb do
    case params["action"]
    when "show"
      [ link_to(MailTemplate.model_name.human(count: 2), mail_templates_path) ]
    when "edit", "update"
      [
        link_to(MailTemplate.model_name.human(count: 2), mail_templates_path),
        link_to(resource.display_name, resource)
      ]
    end
  end

  scope :all
  scope :member
  scope :membership
  scope :invoice
  scope -> { Absence.model_name.human }, :absence,
    if: -> { Current.org.feature?("absence") }
  scope -> { Activity.model_name.human }, :activity,
    if: -> { Current.org.feature?("activity") }

  action_item :view, only: :index, if: -> { authorized?(:update, Organization) } do
    link_to t(".settings"), edit_organization_path(anchor: "mail"), class: "action-item-button"
  end

  index download_links: false do
    column :title, ->(mt) {
      div link_to(mt.display_name, mt)
      span mt.description, class: "mt-1 description"
    }
    column :active, sortable: false, class: "text-right"
    actions
  end

  show do |mail_template|
    columns do
      column "data-controller" => "iframe" do
        Current.org.languages.each do |locale|
          title = t(".preview")
          title += " (#{t("languages.#{locale}")})" if Current.org.languages.many?
          panel title do
            div class: "iframe-wrapper" do
              iframe(
                srcdoc: mail_template.mail_preview(locale),
                scrolling: "no",
                class: "mail_preview",
                id: "mail_preview_#{locale}",
                "data-iframe-target" => "iframe")
            end
          end
        end
      end
      column do
        panel t(".details") do
          div class: "mx-2 mb-4" do
            para mail_template.description, class: "text-base description"
          end
          if !mail_template.active? || !mail_template.with_delivery_cycles_scope?
            attributes_table do
              row(:active, class: "text-right") { status_tag(mail_template.active?) }
            end
          else
            table_for DeliveryCycle.kept.ordered, class: "table-auto" do
              column DeliveryCycle.model_name.human, ->(dc) { auto_link dc }
              column MailTemplate.human_attribute_name(:active), ->(dc) {
                status_tag(dc.id.in?(mail_template.delivery_cycle_ids))
              }, class: "text-right"
            end
          end
        end
      end
    end
  end

  form data: {
    controller: "code-editor",
    code_editor_target: "form",
    code_editor_preview_path_value: "/mail_templates/preview.js",
    turbo: false
  } do |f|
    f.inputs t(".settings") do
      para f.object.description, class: "text-base description"
      f.input :title, as: :hidden

      div "data-controller" => "form-checkbox-toggler" do
        if mail_template.always_active?
          f.input :active,
            input_html: { disabled: true },
            required: false,
            hint: t("formtastic.hints.mail_template.always_active")
        elsif mail_template.title == "invoice_overdue_notice" && !Current.org.automatic_payments_processing?
          f.input :active,
            input_html: { disabled: true },
            required: false,
            hint: t("formtastic.hints.mail_template.invoice_overdue_notice")
        else
          f.input :active,
            hint: !mail_template.active?,
            input_html: { data: {
              form_checkbox_toggler_target: "checkbox",
              action: "form-checkbox-toggler#toggleInput"
            } }
        end
        if mail_template.with_delivery_cycles_scope? && DeliveryCycle.kept.many?
          f.input :delivery_cycle_ids,
            as: :check_boxes,
            collection: admin_delivery_cycles_collection,
            input_html: {
              data: { form_checkbox_toggler_target: "input" }
            },
            label: DeliveryCycle.model_name.human(count: 2)
        end
      end
    end
    f.inputs do
      translated_input(f, :subjects,
        hint: t("formtastic.hints.liquid_html"),
        input_html: {
          data: { action: "code-editor#updatePreview" }
        })
      translated_input(f, :contents,
        as: :text,
        hint: t("formtastic.hints.liquid_html"),
        input_html: {
          data: { mode: "liquid", code_editor_target: "editor" }
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
                  srcdoc: mail_template.mail_preview(locale),
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
                  name: "mail_template[liquid_data_preview_yamls][#{locale}]"
                })
            end
          end
      end
    end
    f.actions
  end

  permit_params(
    :active,
    *I18n.available_locales.map { |l| "subject_#{l}" },
    *I18n.available_locales.map { |l| "content_#{l}" },
    liquid_data_preview_yamls: I18n.available_locales,
    delivery_cycle_ids: [])

  collection_action :preview, method: :post do
    @mail_template = scoped_collection.where(title: params[:mail_template][:title]).first!
    resource.assign_attributes(permitted_params[:mail_template])
    render :preview
  end

  controller do
    skip_before_action :verify_authenticity_token, only: :preview

    def scoped_collection
      scoped = end_of_association_chain
      unless Current.org.feature?("activity")
        scoped = scoped.where.not(title: MailTemplate::ACTIVITY_TITLES)
      end
      # Order by title
      order_clause = MailTemplate::TITLES.each_with_index.map do |title, index|
        "WHEN #{ActiveRecord::Base.connection.quote(title)} THEN #{index + 1}"
      end.join(" ")
      order_sql = "CASE title #{order_clause} ELSE #{MailTemplate::TITLES.size + 1} END"
      scoped.order(Arel.sql(order_sql))
    end

    def find_resource
      scoped_collection.where(title: params[:id]).first!
    end

    def update(options = {}, &block)
      resource.assign_attributes(permitted_params[:mail_template])
      if resource.valid? && (params.keys & %w[preview edit]).any?
        render :edit
      else
        super
      end
    end
  end

  config.filters = false
  config.sort_order = "" # use custom order defined in scoped_collection
end
