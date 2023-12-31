class MembershipMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def last_trial_basket_email
    params.merge!(last_trial_basket_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_last_trial_basket)
    MembershipMailer.with(params).last_trial_basket_email
  end

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

  def last_trial_basket_email_params
    {
      basket: basket,
      member: member,
      membership: membership
    }
  end

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
