# frozen_string_literal: true

module Inbound
  module Postmark
    class WebhooksController < ActionController::API
      include ActionController::HttpAuthentication::Basic::ControllerMethods

      before_action :authenticate!

      def create
        address = Support::InboundAddress.parse(*recipient_addresses)
        if address&.recognized? && !address.demo?
          Tenant.switch(address.tenant) {
            Support::InboundJob.perform_later(sliced_payload)
          }
        end
        head :ok
      end

      private

      def authenticate!
        password = Support::Ticket.inbound_webhook_password
        if password.blank?
          head :unauthorized
          return
        end

        authenticate_or_request_with_http_basic do |_user, pass|
          ActiveSupport::SecurityUtils.secure_compare(pass.to_s, password)
        end
      end

      def recipient_addresses
        [
          params[:ToFull],
          params[:OriginalRecipient],
          params[:To]
        ]
      end

      def sliced_payload
        params.permit(
          :From, :FromName, :To, :OriginalRecipient,
          :Subject, :TextBody, :HtmlBody, :StrippedTextReply, :MessageID,
          FromFull: [ :Email, :Name, :MailboxHash ],
          ToFull: [ :Email, :Name, :MailboxHash ],
          Headers: [ :Name, :Value ],
          Attachments: [ :Name, :Content, :ContentType, :ContentLength, :ContentID ]
        ).to_h
      end
    end
  end
end
