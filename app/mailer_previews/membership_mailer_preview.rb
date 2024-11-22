# frozen_string_literal: true

class MembershipMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def initial_basket_email
    params.merge!(initial_basket_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_initial_basket)
    MembershipMailer.with(params).initial_basket_email
  end

  def final_basket_email
    params.merge!(final_basket_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_final_basket)
    MembershipMailer.with(params).final_basket_email
  end

  def first_basket_email
    params.merge!(first_basket_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_first_basket)
    MembershipMailer.with(params).first_basket_email
  end

  def last_basket_email
    params.merge!(last_basket_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :membership_last_basket)
    MembershipMailer.with(params).last_basket_email
  end

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

  def initial_basket_email_params; basket_params; end
  def final_basket_email_params; basket_params; end
  def first_basket_email_params; basket_params; end
  def last_basket_email_params; basket_params; end
  def last_trial_basket_email_params; basket_params; end

  def basket_params
    {
      basket: basket,
      member: member,
      membership: membership
    }
  end

  def renewal_email_params; membership_params; end
  def renewal_reminder_email_params; membership_params; end

  def membership_params
    {
      member: member,
      membership: membership
    }
  end
end
