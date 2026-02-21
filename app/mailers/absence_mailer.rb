# frozen_string_literal: true

class AbsenceMailer < ApplicationMailer
  include Templatable

  def created_email
    absence = params[:absence]
    member = absence.member
    template_mail(member,
      tag: "absence-created",
      "member" => Liquid::MemberDrop.new(member),
      "absence" => Liquid::AbsenceDrop.new(absence))
  end

  def baskets_shifted_email
    absence = params[:absence]
    member = absence.member
    basket_shifts = absence.basket_shifts.includes(source_basket: :delivery, target_basket: :delivery)
    template_mail(member,
      tag: "absence-baskets-shifted",
      "member" => Liquid::MemberDrop.new(member),
      "absence" => Liquid::AbsenceDrop.new(absence),
      "basket_shifts" => basket_shifts.map { |bs| Liquid::BasketShiftDrop.new(bs) })
  end
end
