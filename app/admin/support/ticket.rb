# frozen_string_literal: true

ActiveAdmin.register Support::Ticket do
  menu false

  config.sort_order = "last_activity_at_desc"
  config.comments = false
  config.batch_actions = false
  config.clear_action_items!

  breadcrumb do
    links = []
    unless params[:action] == "index"
      links << link_to(I18n.t("active_admin.resources.support/ticket.menu"), support_tickets_path)
    end
    links
  end

  scope :all
  scope :waiting, group: :state, default: true
  scope :replied, group: :state

  filter :text_cont, as: :string,
    label: -> { I18n.t("active_admin.resources.support/ticket.filters.text") }
  filter :admin, as: :select,
    collection: -> { ticket_admins_collection(collection) },
    label: -> { Support::Ticket.human_attribute_name(:admin) }
  filter :priority, as: :select,
    collection: -> { ticket_priority_marks_collection }
  filter :last_activity_at, as: :date_range

  includes :admin, :last_message
  index download_links: false,
    blank_slate_content: -> { t("active_admin.resources.support/ticket.blank_slate.content") },
    blank_slate_link: -> {
      action_link t("active_admin.resources.support/ticket.new_model"),
        new_support_ticket_path,
        icon: "pencil-line"
    } do
    column :subject, ->(ticket) {
      auto_link ticket, ticket.subject_with_priority, data: { "table-row-action": "show" }
    }
    column :admin, ->(ticket) {
      if ticket.admin
        auto_link ticket.admin
      else
        span t("active_admin.unknown"), class: "support-unknown"
      end
    }
    column :state, ->(ticket) {
      next unless ticket.state

      aligned_status_tag ticket.state,
        label: t("states.support/ticket.#{ticket.state}")
    }, class: "text-right"
    column :last_activity_at, ->(ticket) { l(ticket.last_activity_at, format: :short) },
      class: "text-right is-nowrap"
  end

  action_item :new, only: :index, if: -> { authorized?(:create, Support::Ticket) } do
    action_link t("active_admin.resources.support/ticket.new_model"),
      new_support_ticket_path,
      icon: "pencil-line"
  end

  action_item :edit, only: :show, if: -> { authorized?(:update, resource) } do
    action_link t("active_admin.edit_model"), edit_resource_path, icon: "square-pen"
  end

  action_item :destroy, only: :show, if: -> { authorized?(:destroy, resource) } do
    action_button t("active_admin.delete_model"), resource_path,
      method: :delete,
      icon: "trash",
      class: "destructive",
      data: { confirm: t("active_admin.delete_confirmation") }
  end

  form do |f|
    if Tenant.demo?
      info_pane do
        t("active_admin.resources.support/ticket.demo_disabled_html").html_safe
      end
    end

    div class: "support-ticket-form" do
      f.inputs do
        div class: "support-ticket-subject-row" do
          f.input :subject, hint: false, wrapper_html: { class: "is-grow" }
          f.input :priority,
            collection: ticket_priority_marks_collection,
            include_blank: false,
            label: false,
            wrapper_html: { class: "support-ticket-priority" },
            input_html: {
              "aria-label": Support::Ticket.human_attribute_name(:priority)
            }
        end
        if f.object.new_record?
          f.input :html,
            as: :action_text,
            label: Support::Ticket.human_attribute_name(:content),
            hint: true
          render partial: "active_admin/attachments/form", locals: { f: f, add_icon: "paperclip" }
        else
          f.input :context, input_html: { rows: 2 }
        end
      end
    end

    unless Tenant.demo?
      f.actions do
        f.action :submit,
          label: f.object.new_record? ? t("active_admin.resources.support/ticket.submit") : t("active_admin.update_model"),
          icon: f.object.new_record? ? "send-horizontal" : "check"
        cancel_link f.object.persisted? ? resource_path : collection_path
      end
    end
  end

  show title: ->(ticket) { ticket.display_title } do |ticket|
    panel Support::Message.model_name.human(count: 2), icon: "message-square-text", count: ticket.messages.size do
      div class: "support-conversation" do
        div class: "support-thread" do
          ticket.messages.includes(attachments: { file_attachment: :blob }).order(:id).each do |message|
            images, files = support_message_attachments(message)
            div class: "support-message is-#{message.author}" do
              div class: "support-message-meta" do
                span class: [ "support-message-author", ("support-unknown" if message.unknown_author?) ].compact.join(" ") do
                  message.display_name
                end
                span class: "support-message-time" do
                  l(message.created_at, format: :short)
                end
              end
              div class: "support-message-body trix-content" do
                support_message_html(message)
              end
              if images.any?
                div class: "support-message-images" do
                  images.each do |attachment|
                    text_node support_inline_image(attachment.file)
                  end
                end
              end
              if files.any?
                div class: "support-message-files" do
                  div class: "support-message-files-title" do
                    text_node icon("paperclip", class: "icon-4")
                    span Attachment.model_name.human(count: 2)
                  end
                  ul class: "disc-list is-outside stack is-snug" do
                    files.each do |attachment|
                      li { display_attachment(attachment.file) }
                    end
                  end
                end
              end
            end
          end
        end

        if ticket.marked_as_replied?
          para class: "support-replied-note" do
            t("active_admin.resources.support/ticket.marked_as_replied",
              name: ENV.fetch("ULTRA_ADMIN_NAME", "CSA Admin"),
              at: l(ticket.replied_at, format: :short))
          end
        elsif authorized?(:mark_as_replied, ticket) && !Tenant.demo? && ticket.waiting?
          div class: "support-mark-replied" do
            panel_button t("active_admin.resources.support/ticket.mark_as_replied"),
              mark_as_replied_support_ticket_path(ticket),
              icon: "check"
          end
        end

        unless Tenant.demo?
          div class: "support-reply" do
            active_admin_form_for @support_message || Support::Message.new,
              url: reply_support_ticket_path(ticket),
              html: { class: "support-reply-form", multipart: true } do |f|
              f.semantic_errors :attachments
              ol do
                f.input :html, as: :action_text, label: false, input_html: { rows: 10 }
              end
              div class: "support-reply-toolbar" do
                div class: "support-reply-actions" do
                  f.action :submit,
                    label: t("active_admin.resources.support/ticket.submit"),
                    icon: "send-horizontal",
                    icon_class: "icon-4",
                    button_html: { class: "btn btn-sm" }
                end
                render partial: "active_admin/attachments/form", locals: { f: f, add_icon: "paperclip" }
              end
            end
          end
        end
      end
    end
  end

  permit_params do
    if action_name == "create"
      [ :priority, :subject, :html, attachments_attributes: [ :id, :file, :_destroy ] ]
    else
      [ :priority, :subject, :context ]
    end
  end

  member_action :mark_as_replied, method: :post do
    authorize! :mark_as_replied, resource
    if Tenant.demo?
      redirect_to resource_path, alert: t("active_admin.resources.support/ticket.demo_disabled")
    else
      resource.mark_as_replied!
      redirect_to resource_path, notice: t("active_admin.resources.support/ticket.flash.marked_as_replied")
    end
  end

  member_action :reply, method: :post do
    authorize! :create, Support::Message
    message = resource.messages.build(reply_params)
    message.author = current_admin.ultra? ? "support" : "admin"
    message.admin = current_admin unless current_admin.ultra?
    message.via = :app
    if Tenant.demo?
      redirect_to resource_path, alert: t("active_admin.resources.support/ticket.demo_disabled")
    elsif message.save
      redirect_to resource_path, notice: t("active_admin.resources.support/ticket.flash.replied")
    else
      @support_message = message
      render :show, status: :unprocessable_entity
    end
  end

  controller do
    before_action :remember_support_context, only: %i[index new]

    before_build do |ticket|
      ticket.priority ||= :normal
      ticket.context ||= session[:support_context].presence || support_context_from_referer
    end

    before_create do |ticket|
      ticket.admin = current_admin
      ticket.context ||= session[:support_context].presence
    end

    def create
      if Tenant.demo?
        redirect_to new_support_ticket_path, alert: t("active_admin.resources.support/ticket.demo_disabled")
        return
      end

      create! do |success, _failure|
        success.html {
          session.delete(:support_context)
          redirect_to resource_path, notice: t("active_admin.resources.support/ticket.flash.notice")
        }
      end
    end

    def update
      update! do |success, _failure|
        success.html { redirect_to resource_path }
      end
    end

    def find_resource
      scoped_collection.find_by!(token: params[:id])
    end

    def scoped_collection
      Tenant.demo? ? super.none : super
    end

    private

    def remember_support_context
      url = support_context_from_referer
      session[:support_context] = url if url
    end

    def support_context_from_referer
      return if request.referer.blank?

      referrer_url = URI.decode_uri_component(request.referer)
      uri = URI.parse(referrer_url)
      return if uri.path.blank? || uri.path == "/" || uri.path == "/dashboard"
      return if uri.path.start_with?("/support")
      return unless uri.host == request.host

      referrer_url
    rescue URI::InvalidURIError
      nil
    end

    def reply_params
      params.require(:support_message).permit(
        :html,
        attachments_attributes: [ :id, :file, :_destroy ])
    end
  end
end
