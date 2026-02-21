# frozen_string_literal: true

require "ostruct"

class AbsenceMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def created_email
    params.merge!(created_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :absence_created)
    AbsenceMailer.with(params).created_email
  end

  def baskets_shifted_email
    params.merge!(baskets_shifted_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :absence_baskets_shifted)
    AbsenceMailer.with(params).baskets_shifted_email
  end

  private

  def created_email_params
    { absence: absence, member: member }
  end

  def baskets_shifted_email_params
    { absence: absence_with_shifts, member: member }
  end

  def absence_with_shifts
    a = absence
    shifts = [ basket_shift ]
    a.define_singleton_method(:basket_shifts) do
      relation = shifts
      relation.define_singleton_method(:includes) { |*_args| self }
      relation
    end
    a
  end

  def absence
    OpenStruct.new(
      member: member,
      started_on: absence_date - 1.day,
      ended_on: absence_date + 6.days,
      note: "",
      baskets: [ Basket.new ]
    )
  end

  def basket_shift
    shift = OpenStruct.new(
      absence: absence,
      source_basket: basket,
      target_basket: OpenStruct.new(
        delivery: OpenStruct.new(date: absence_date + 7.days)))
    shift.define_singleton_method(:description) do |*args|
      source_basket.basket_size.public_name
    end
    shift
  end

  def absence_date
    @absence_date ||= basket&.delivery&.date || 1.week.from_now.to_date
  end

  def basket
    super || OpenStruct.new(
      delivery: OpenStruct.new(
        date: 1.week.from_now.to_date),
        basket_size: basket_size)
  end
end
