# frozen_string_literal: true

class BasketMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def initial_email
    params.merge!(initial_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :basket_initial)
    BasketMailer.with(params).initial_email
  end

  def final_email
    params.merge!(final_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :basket_final)
    BasketMailer.with(params).final_email
  end

  def first_email
    params.merge!(first_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :basket_first)
    BasketMailer.with(params).first_email
  end

  def last_email
    params.merge!(last_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :basket_last)
    BasketMailer.with(params).last_email
  end

  def second_last_trial_email
    params.merge!(second_last_trial_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :basket_second_last_trial)
    BasketMailer.with(params).second_last_trial_email
  end

  def last_trial_email
    params.merge!(last_trial_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :basket_last_trial)
    BasketMailer.with(params).last_trial_email
  end

  private

  def initial_email_params = basket_params
  def final_email_params = basket_params
  def first_email_params = basket_params
  def last_email_params = basket_params
  def second_last_trial_email_params = basket_params
  def last_trial_email_params = basket_params

  def basket_params
    {
      basket: basket,
      member: member,
      membership: membership
    }
  end
end
