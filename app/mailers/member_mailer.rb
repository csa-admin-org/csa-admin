class MemberMailer < ApplicationMailer
  include Templatable

  def activated_email
    member = params[:member]
    membership = params[:membership]
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'membership' => Liquid::MembershipDrop.new(membership))
  end

  def validated_email
    member = params[:member]
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'waiting_list_position' => Member.waiting.count + 1)
  end
end
