# frozen_string_literal: true

module StatesHelper
  def state_color(object)
    case object.state
    when "processing", "canceled"
      "gray"
    when "open", "rejected"
      "red"
    when "closed", "validated"
      "green"
    end
  end
end
