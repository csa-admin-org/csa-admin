# frozen_string_literal: true

ActiveAdmin.register Support::Ticket do
  menu false
  actions :new, :create

  form do |f|
    f.inputs do
      f.input :priority,
        collection: ticket_priorities_collection,
        include_blank: false
      f.input :subject
      f.input :content, input_html: { rows: 6 }
      f.input :context, input_html: { rows: 2 }# , hint: I18n.t("formtastic.hints.support_ticket.context")
      render partial: "active_admin/attachments/form", locals: { f: f }
    end

    f.actions do
      f.submit t("active_admin.resources.support/ticket.submit")
    end
  end

  permit_params \
    :priority, :subject, :context, :content,
    attachments_attributes: [ :id, :file, :_destroy ]

  controller do
    before_build do |ticket|
      if request&.referer
        referrer_url = URI.decode_uri_component(request&.referer)
        unless referrer_url == dashboard_url
          ticket.context ||= referrer_url
        end
      end
    end

    before_create do |ticket|
      ticket.admin = current_admin
    end

    def create
      create! do |success, failure|
        success.html { redirect_to root_url, notice: t("active_admin.resources.support/ticket.flash.notice") }
      end
    end
  end
end
