# frozen_string_literal: true

require "net/http"

class Support::TicketNotifyJob < ApplicationJob
  retry_on Net::OpenTimeout, Net::ReadTimeout, Socket::ResolutionError,
    OpenSSL::SSL::SSLError, Errno::ECONNRESET, Errno::ECONNREFUSED,
    wait: :polynomially_longer

  def perform(ticket)
    url = Support::Ticket.webhook_url
    return unless url

    authorization = Support::Ticket.webhook_authorization
    return unless authorization

    uri = URI(url)
    request = Net::HTTP::Post.new(uri,
      "Content-Type" => "application/json",
      "Authorization" => authorization)
    request.body = Support::Ticket::WebhookPayload.new(ticket).to_json

    response = Net::HTTP.start(uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 3,
      read_timeout: 5) do |http|
      http.request(request)
    end
    Rails.logger.info { "Support webhook POST #{response.code}" }
    response
  end
end
