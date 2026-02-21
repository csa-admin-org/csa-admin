# frozen_string_literal: true

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

  def absence_included_reminder_email
    params.merge!(absence_included_reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :absence_included_reminder)
    MembershipMailer.with(params).absence_included_reminder_email
  end

  private

  def renewal_email_params = membership_params
  def renewal_reminder_email_params = membership_params
  def absence_included_reminder_email_params = membership_params

  def membership_params
    {
      membership: membership,
      member: member
    }
  end
end
