# frozen_string_literal: true

require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "store created_by via audit" do
    payment = create_payment
    assert_equal System.instance, payment.created_by

    Current.session = sessions(:master)
    payment = create_payment
    assert_equal admins(:master), payment.created_by
  end

  test "store updated_by" do
    payment = create_payment
    assert_nil payment.updated_by

    payment.update(amount: 1)
    assert_equal System.instance, payment.updated_by

    Current.session = sessions(:master)
    payment.update(amount: 2)
    assert_equal admins(:master), payment.updated_by
  end
end
