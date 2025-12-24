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

  def included_reminder_email
    membership = params[:membership]
    member = params[:member] || membership&.member
    template_mail(member,
      tag: "absence-included-reminder",
      "member" => Liquid::MemberDrop.new(member),
      "membership" => Liquid::MembershipDrop.new(membership))
  end
end
