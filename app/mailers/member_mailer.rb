class MemberMailer < ApplicationMailer
  include Templatable

  def activated_email
    member = params[:member]
    membership = member.current_or_future_membership
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'membership' => Liquid::MembershipDrop.new(membership))
  end

  def validated_email
    member = params[:member]
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'waiting_list_position' => Member.waiting.count + 1,
      'waiting_basket_size_id' => member.waiting_basket_size_id,
      'waiting_depot_id' => member.waiting_depot_id)
  end
end
