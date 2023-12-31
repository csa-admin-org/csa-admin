class MemberMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def activated_email
    params.merge!(activated_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :member_activated)
    MemberMailer.with(params).activated_email
  end

  def validated_email
    params.merge!(validated_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :member_validated)
    MemberMailer.with(params).validated_email
  end

  private

  def activated_email_params
    {
      member: member,
      membership: membership,
      basket: basket
    }
  end

  def validated_email_params
    {
      member: member,
      waiting_list_position: Member.waiting.count + 1,
      waiting_basket_size_id: member.waiting_basket_size_id,
      waiting_depot_id: member.waiting_depot_id
    }
  end
end
