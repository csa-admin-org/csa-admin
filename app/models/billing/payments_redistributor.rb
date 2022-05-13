module Billing
  class PaymentsRedistributor
    def self.redistribute!(member_id)
      new(member_id).redistribute!
    end

    def initialize(member_id)
      @member = Member.find(member_id)
      @remaining_amounts = Hash.new(0)
      @remaining_amount = 0
    end

    def redistribute!
      @member.transaction do
        clear_all_paid_amount!
        pay_targeted_invoices_first!
        pay_remaining_amounts_to_same_object_type_invoices!
        pay_remaining_amount_chronogically!
      end
    end

    private

    def clear_all_paid_amount!
      @member.invoices.update_all(paid_amount: 0)
    end

    # Use payment amount to targeted invoice first.
    def pay_targeted_invoices_first!
      payments.each do |payment|
        if payment.invoice
          if payment.invoice.canceled?
            @remaining_amounts[payment.invoice.object_type] += payment.amount
          else
            paid_amount = [[payment.amount, payment.invoice.missing_amount].min, 0].max
            payment.invoice.increment!(:paid_amount, paid_amount)
            @remaining_amounts[payment.invoice.object_type] += payment.amount - paid_amount
          end
        else
          @remaining_amount += payment.amount
        end
      end
    end

    # Split remaining amounts on other invoices with the same object type chronogically
    def pay_remaining_amounts_to_same_object_type_invoices!
      @remaining_amounts.each do |object_type, rem_amount|
        invoices.where(object_type: object_type).each do |invoice|
          if invoice.missing_amount.positive? && rem_amount.positive?
            paid_amount = [rem_amount, invoice.missing_amount].min
            invoice.increment!(:paid_amount, paid_amount)
            rem_amount -= paid_amount
          end
          invoice.reload.close_or_open!
        end
        @remaining_amount += rem_amount
      end
    end

    # Split remaining amount on other invoices chronogically
    def pay_remaining_amount_chronogically!
      # Add negative (payback) invoice to remaining_amount
      @remaining_amount += -invoices.where('amount < 0').sum(:amount)

      last_invoice = invoices.last
      invoices.each do |invoice|
        if invoice == last_invoice
          invoice.increment!(:paid_amount, @remaining_amount)
        elsif invoice.missing_amount.positive?
          paid_amount = [@remaining_amount, invoice.missing_amount].min
          invoice.increment!(:paid_amount, paid_amount)
          @remaining_amount -= paid_amount
        end
        invoice.reload.close_or_open!
      end
    end

    def payments
      @member.payments
    end

    def invoices
      @member.invoices.not_canceled.order(:date, :id)
    end
  end
end
