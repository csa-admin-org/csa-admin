class MembershipMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def renewal_email
    params.merge!(renewal_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_renewal)
    MembershipMailer.with(params).renewal_email
  end

  def renewal_reminder_email
    params.merge!(renewal_reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_renewal_reminder)
    MembershipMailer.with(params).renewal_reminder_email
  end

  private

  def renewal_email_params
    {
      member: member,
      membership: membership
    }
  end

  def renewal_reminder_email_params
    {
      member: member,
      membership: membership
    }
  end
end


