# frozen_string_literal: true

class BiddingRoundMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def opened_email
    params.merge!(opened_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :bidding_round_opened)
    BiddingRoundMailer.with(params).opened_email
  end

  def opened_reminder_email
    params.merge!(opened_reminder_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :bidding_round_opened_reminder)
    BiddingRoundMailer.with(params).opened_reminder_email
  end

  def completed_email
    params.merge!(completed_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :bidding_round_completed)
    BiddingRoundMailer.with(params).completed_email
  end

  def failed_email
    params.merge!(failed_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :bidding_round_failed)
    BiddingRoundMailer.with(params).failed_email
  end

  private

  def opened_email_params = bidding_round_params
  def opened_reminder_email_params = bidding_round_params

  def completed_email_params
    bidding_round_params.merge(
      bidding_round_pledge: pledge(membership.basket_size))
  end

  def failed_email_params
    bidding_round_params.merge(
      bidding_round_pledge: pledge(membership.basket_size))
  end

  def bidding_round_params
    {
      member: member,
      membership: membership,
      bidding_round: bidding_round
    }
  end

  def bidding_round
    BiddingRound.current_draft
      || BiddingRound.current_open
      || BiddingRound.new(
        number: 1,
        fy_year: Date.current.year,
        information_text: I18n.t("bidding_rounds.preview_information_text"))
  end

  def pledge(basket_size)
    BiddingRound::Pledge.new(basket_size_price: basket_size.price + 1)
  end
end
