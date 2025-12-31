# frozen_string_literal: true

module QRCodeHelper
  def skip_qr_code_placeholder
    with_env("SKIP_QR_CODE_PLACEHOLDER" => "true") { yield }
  end
end
