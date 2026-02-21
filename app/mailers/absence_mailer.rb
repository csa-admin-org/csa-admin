# frozen_string_literal: true

class AbsenceMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def created_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "absence" => Liquid::AbsenceDrop.new(@absence))
  end

  def baskets_shifted_email
    basket_shifts = @absence.basket_shifts.includes(source_basket: :delivery, target_basket: :delivery)
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "absence" => Liquid::AbsenceDrop.new(@absence),
      "basket_shifts" => basket_shifts.map { |bs| Liquid::BasketShiftDrop.new(bs) })
  end

  private

  def set_context
    @absence = params[:absence]
    @member = @absence.member
  end
end
