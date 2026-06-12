# frozen_string_literal: true

module CapHelper
  include TooltipHelper

  def cap_token_field
    tag.div(
      data: {
        controller: "cap",
        "cap-api-endpoint-value" => cap_api_endpoint,
        "cap-wasm-url-value" => "#{Cap.api_url}/assets/cap_wasm_bg.wasm",
        "cap-verifying-message-value" => t("cap.verifying"),
        "cap-failed-message-value" => t("cap.failed"),
        "cap-unavailable-message-value" => t("cap.unavailable")
      }) do
      safe_join([
        hidden_field_tag("cap-token", nil, data: { "cap-target" => "token" }),
        tag.template(data: { "cap-target" => "tooltipTemplate" }) { tooltip_element("") }
      ])
    end
  end

  def cap_submit_tooltip_data
    {
      controller: "tooltip",
      "tooltip-dismissible-value" => true,
      "tooltip-placement-value" => "top"
    }
  end

  def cap_submit_tooltip_target_data
    { "tooltip-target" => "trigger" }
  end

  private

  def cap_api_endpoint
    site_key = Cap.site_key
    raise "Missing Cap site key for #{Tenant.current}" if site_key.blank? && Rails.env.production?
    return unless site_key.present?

    "#{Cap.api_url}/#{site_key}/"
  end
end
