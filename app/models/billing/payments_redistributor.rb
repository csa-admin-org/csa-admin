module Billing
  class PaymentsRedistributor
    def self.redistribute!(member_id)
      new(member_id).redistribute!
    end

    def initialize(member_id)
      @member = Member.find(member_id)
      @remaining_amounts = {}
      @remaining_amount = 0
    end

    def redistribute!
      @member.transaction do
        clear_all_paid_amount!
        remove_payback_invoices_to_remaining_amount!
        pay_targeted_invoices!
        pay_remaining_amount_chronogically!(scope: :closed)
        pay_remaining_amount_chronogically!
        pay_remaining_amount_on_last_invoice!
        close_or_open_invoices!
      end
    end

    private

    def clear_all_paid_amount!
      @member.invoices.update_all(paid_amount: 0)
    end

    def close_or_open_invoices!
      invoices.find_each(&:close_or_open!)
    end

    def remove_payback_invoices_to_remaining_amount!
      @remaining_amount -= invoices.where(amount: ...0).sum(:amount)
    end

    # Use payment amount to targeted invoice.
    def pay_targeted_invoices!
      payments.each do |pm|
        if pm.invoice
          if pm.invoice.canceled?
            @remaining_amount += pm.amount
          else
            paid_amount = [[pm.amount, pm.invoice.missing_amount].min, 0].max
            pm.invoice.increment!(:paid_amount, paid_amount)
            @remaining_amount += pm.amount - paid_amount
          end
        else
          @remaining_amount += pm.amount
        end
      end
    end

    # Split remaining amount on invoices chronogically.
    def pay_remaining_amount_chronogically!(scope: :all)
      return if @remaining_amount.zero?

      invoices.send(scope).each do |invoice|
        paid_amount = [@remaining_amount, invoice.missing_amount].min
        invoice.increment!(:paid_amount, paid_amount)
        @remaining_amount -= paid_amount
      end
    end

    def pay_remaining_amount_on_last_invoice!
      return if @remaining_amount.zero?

      invoices.last&.increment!(:paid_amount, @remaining_amount)
    end

    def payments
      @member.payments
    end

    def invoices
      @member.invoices.not_canceled.order(:date, :id)
    end
  end
end
