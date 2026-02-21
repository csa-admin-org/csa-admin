# frozen_string_literal: true

class BiddingRoundMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def opened_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership),
      "bidding_round" => Liquid::BiddingRoundDrop.new(@bidding_round))
  end

  def opened_reminder_email
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership),
      "bidding_round" => Liquid::BiddingRoundDrop.new(@bidding_round))
  end

  def completed_email
    @subject_class = "notice"
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership),
      "bidding_round" => Liquid::BiddingRoundDrop.new(@bidding_round),
      "bidding_round_pledge" => Liquid::BiddingRoundPledgeDrop.new(@pledge))
  end

  def failed_email
    @subject_class = "alert"
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "membership" => Liquid::MembershipDrop.new(@membership),
      "bidding_round" => Liquid::BiddingRoundDrop.new(@bidding_round),
      "bidding_round_pledge" => Liquid::BiddingRoundPledgeDrop.new(@pledge))
  end

  private

  def set_context
    @bidding_round = params[:bidding_round]
    @member = params[:member]
    @membership = @member.memberships.during_year(@bidding_round.fiscal_year).first
    @pledge = params[:bidding_round_pledge] || @bidding_round.pledges.find_by(membership: @membership)
  end
end
