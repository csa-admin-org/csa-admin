# frozen_string_literal: true

module FlashMessagesHelper
  def flash_error
    find("[aria-label=\"#{I18n.t("accessibility.active_admin.flash.error")}\"]")&.text
  end

  def flash_alert
    find("[aria-label=\"#{I18n.t("accessibility.active_admin.flash.alert")}\"]")&.text
  end

  def flash_notice
    find("[aria-label=\"#{I18n.t("accessibility.active_admin.flash.notice")}\"]")&.text
  end
end
