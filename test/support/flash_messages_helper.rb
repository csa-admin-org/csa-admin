module FlashMessagesHelper
  def flash_error
    find("[aria-label=\"flash error\"]")&.text
  end

  def flash_alert
    find("[aria-label=\"flash alert\"]")&.text
  end

  def flash_notice
    find("[aria-label=\"flash notice\"]")&.text
  end
end
