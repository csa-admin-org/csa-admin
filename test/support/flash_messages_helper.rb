# frozen_string_literal: true

module FlashMessagesHelper
  def flash_error
    find("[aria-label=\"Flash error\"]")&.text
  end

  def flash_alert
    find("[aria-label=\"Flash alert\"]")&.text
  end

  def flash_notice
    find("[aria-label=\"Flash notice\"]")&.text
  end
end
