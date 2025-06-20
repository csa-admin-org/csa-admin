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

  def basket_shifted_email
    basket_shift = params[:basket_shift]
    absence = basket_shift.absence
    member = absence.member
    template_mail(member,
      tag: "absence-basket-shifted",
      "member" => Liquid::MemberDrop.new(member),
      "absence" => Liquid::AbsenceDrop.new(absence),
      "basket_shift" => Liquid::BasketShiftDrop.new(basket_shift))
  end
end
