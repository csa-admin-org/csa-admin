# frozen_string_literal: true

module Postmark
  class WebhooksController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate!

    RECORD_TYPES = %w[Delivery Bounce]
    MESSAGE_STREAMS = %w[broadcast]

    def create
      if supported_payload?
        WebhookHandlerJob.perform_later(**payload)
      else
        SLog.log(:unsupported_postmark_webhook, **payload)
      end
      head :ok
    end

    private

    def authenticate!
      authenticate_or_request_with_http_token do |token, options|
        ActiveSupport::SecurityUtils.secure_compare(token, Postmark.webhook_token)
      end
    end

    def supported_payload?
      payload[:record_type].in?(RECORD_TYPES) &&
        payload[:message_stream].in?(MESSAGE_STREAMS)
    end

    def payload
      @payload ||=
        HashHelper
          .to_ruby(params.to_unsafe_h)
          .slice(*%i[
            record_type
            message_stream
            message_id
            recipient
            email
            tag
            delivered_at
            bounced_at
            type
            type_code
            description
            details
          ])
    end
  end
end
