# frozen_string_literal: true

module Billing
  class EBICS
    GET_PAYMENTS_FROM = 1.month.ago

    def initialize(credentials = {})
      @credentials = credentials
    end

    def payments_data
      files = get_camt54_files
      CamtFile.new(files).payments_data
    end

    def client
      @client ||= Epics::Client.new(
        @credentials.fetch(:keys),
        @credentials.fetch(:secret),
        @credentials.fetch(:url),
        @credentials.fetch(:host_id),
        @credentials.fetch(:participant_id),
        @credentials.fetch(:client_id))
    end

    private

    def get_camt54_files
      client.Z54(
        GET_PAYMENTS_FROM.to_date.to_s,
        Date.current.to_s)
    rescue Epics::Error::BusinessError => e
      if e.message.include?("EBICS_NO_DOWNLOAD_DATA_AVAILABLE")
        []
      else
        raise e
      end
    end
  end
end
