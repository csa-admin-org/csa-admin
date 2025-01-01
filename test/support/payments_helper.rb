# frozen_string_literal: true

module PaymentsHelper
  def create_payment(attributes = {})
    Payment.create!({
      member: members(:john),
      date: Date.today,
      amount: 100
    }.merge(attributes))
  end
end
