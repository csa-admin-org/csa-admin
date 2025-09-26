# frozen_string_literal: true

module Comchain
  class WebhooksController < ActionController::API
    before_action :ensure_local_currency

    def create
      if LocalCurrency::ComChain.verify_signature(request.raw_post, request.headers)
        LocalCurrency::ComChainWebhookJob.perform_later(params.to_unsafe_hash)
        head :ok
      else
        head :bad_request
      end
    end

    private

    def ensure_local_currency
      return if Current.org.feature?(:local_currency)

      head :unprocessable_entity
    end
  end
end
