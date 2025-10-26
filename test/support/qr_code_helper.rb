# frozen_string_literal: true

module QRCodeHelper
  def skip_qr_code_placeholder
    ENV["SKIP_QR_CODE_PLACEHOLDER"] = "true"
    begin
      yield
    ensure
      ENV["SKIP_QR_CODE_PLACEHOLDER"] = nil
    end
  end
end
