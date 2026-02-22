# frozen_string_literal: true

ActiveAdmin.register MailTemplate do
  menu parent: :email, priority: 2
  actions :index, :show, :edit, :update

  breadcrumb do
    case params["action"]
    when "show"
      [
        link_to(MailTemplate.model_name.human(count: 2), mail_templates_path),
        link_to(resource.scope_label, mail_templates_path(scope: resource.scope_name))
      ]
    when "edit", "update"
      [
        link_to(MailTemplate.model_name.human(count: 2), mail_templates_path),
        link_to(resource.scope_label, mail_templates_path(scope: resource.scope_name)),
        link_to(resource.display_name, resource)
      ]
    end
  end

  scope :all, default: true
  scope :member, group: :type
  scope :membership, group: :type
  scope -> { Basket.model_name.human }, :basket, group: :type
  scope :invoice, group: :type
  scope -> { Absence.model_name.human }, :absence,
    group: :type, if: -> { feature?("absence") }
  scope -> { activity_human_name }, :activity_participation,
    group: :type, if: -> { feature?("activity") }
  scope -> { BiddingRound.model_name.human }, :bidding_round,
    group: :type, if: -> { feature?("bidding_round") }

  action_item :view, only: :index, if: -> { authorized?(:update, Organization) } do
    action_link t(".settings"), edit_organization_path(anchor: "mail"), icon: "adjustments-horizontal"
  end

  action_item :deliveries, only: :show do
    action_link nil, mail_deliveries_path(mail_template_id: resource.id),
      title: MailDelivery.model_name.human(count: 2),
      icon: "mails"
  end

  index download_links: false do
    column :title, ->(mt) {
      div mt.display_name
      span mt.description, class: "block text-sm text-gray-500"
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
              row(:active) { status_tag(mail_template.active?) }
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

        deliveries = mail_template.mail_deliveries
        deliveries_count = deliveries.count
        if deliveries_count > 0
          panel link_to(MailDelivery.model_name.human(count: 2), mail_deliveries_path(mail_template_id: mail_template.id)), count: deliveries_count do
            mail_delivery_email_stats(self, deliveries,
              path_params: { mail_template_id: mail_template.id })
            para t("active_admin.resources.mail_delivery.retention_notice"), class: "mt-6 italic text-sm text-gray-400 dark:text-gray-600"
          end

          if mail_template.show_missing_delivery_emails?
            panel t(".missing_deliveries") do
              missing_delivery_emails_grid(self, mail_template)
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
        elsif mail_template.inactive? && mail_template.title == "invoice_overdue_notice"
          f.input :active,
            input_html: { disabled: true },
            required: false,
            hint: t("formtastic.hints.mail_template.invoice_overdue_notice")
        elsif mail_template.inactive?
          f.input :active,
            input_html: { disabled: true },
            required: false,
            hint: t("formtastic.hints.mail_template.disabled_settings")
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
            for: DeliveryCycle,
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
    include OrganizationsHelper

    def scoped_collection
      scoped = end_of_association_chain
      unless feature?("activity")
        scoped = scoped.where.not(title: MailTemplate::ACTIVITY_PARTICIPATION_TITLES)
      end
      unless feature?("bidding_round")
        scoped = scoped.where.not(title: MailTemplate::BIDDING_ROUND_TITLES)
      end
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
