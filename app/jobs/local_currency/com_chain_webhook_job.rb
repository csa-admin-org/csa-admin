# frozen_string_literal: true

class LocalCurrency::ComChainWebhookJob < ApplicationJob
  def perform(data)
    LocalCurrency::ComChain.handle_webhook(data)
  end
end
