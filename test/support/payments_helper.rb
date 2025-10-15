# frozen_string_literal: true

module PaymentsHelper
  def create_payment(attributes = {})
    Payment.create!({
      member: members(:john),
      date: Date.current,
      amount: 100
    }.merge(attributes))
  end
end
