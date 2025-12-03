# frozen_string_literal: true

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
      invoices.each(&:close_or_open!)
    end

    def remove_payback_invoices_to_remaining_amount!
      @remaining_amount -= invoices.select(&:payback?).sum(&:amount)
    end

    # Use payment amount to targeted invoice.
    def pay_targeted_invoices!
      invoices_by_id = invoices.index_by(&:id)

      payments.each do |pm|
        if invoice = invoices_by_id[pm.invoice_id]
          paid_amount = [ [ pm.amount, invoice.missing_amount ].min, 0 ].max
          invoice.increment!(:paid_amount, paid_amount)
          @remaining_amount += pm.amount - paid_amount
        else
          @remaining_amount += pm.amount
        end
      end
    end

    # Split remaining amount on invoices chronogically.
    def pay_remaining_amount_chronogically!(scope: :all)
      return if @remaining_amount.zero?

      target_invoices = scope == :closed ? invoices.select(&:closed?) : invoices
      target_invoices.each do |invoice|
        paid_amount = [ @remaining_amount, invoice.missing_amount ].min
        invoice.increment!(:paid_amount, paid_amount)
        @remaining_amount -= paid_amount
      end
    end

    def pay_remaining_amount_on_last_invoice!
      return if @remaining_amount.zero?

      invoices.last&.increment!(:paid_amount, @remaining_amount)
    end

    def payments
      @payments ||= @member.payments.not_ignored.to_a
    end

    def invoices
      @invoices ||= @member.invoices.not_canceled.order(:date, :id).to_a
    end
  end
end
