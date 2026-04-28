# frozen_string_literal: true

module UncachedSendData
  extend ActiveSupport::Concern

  included do
    prepend SendDataOverride
  end

  module SendDataOverride
    private

    def send_data(data, options = {})
      result = super

      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"

      result
    end
  end
end
