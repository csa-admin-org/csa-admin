# frozen_string_literal: true

class BiddingRoundMailer < ApplicationMailer
  include Templatable

  before_action :set_membership_and_member
  before_action :set_bidding_round_and_pledge

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

  def set_membership_and_member
    @membership = params[:membership]
    @member = params[:member] || @membership.member
  end

  def set_bidding_round_and_pledge
    @bidding_round = params[:bidding_round]
    @pledge = params[:bidding_round_pledge] || @bidding_round.pledges.find_by(membership: @membership)
  end
end
