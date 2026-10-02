# frozen_string_literal: true

class PriceReductionMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def card_expiring_email
    params.merge!(card_expiring_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :price_reduction_card_expiring)
    PriceReductionMailer.with(params).card_expiring_email
  end

  private

  def card_expiring_email_params
    card_type = PriceReductionCard.new(names: { I18n.locale.to_s => "CarteCulture" })
    # member is an OpenStruct in previews. Do not assign it to belongs_to :member.
    {
      member: member,
      member_card: MemberCard.new(
        price_reduction_card: card_type,
        name: member.name,
        number: "CC-123456",
        expires_on: 1.month.from_now.to_date)
    }
  end
end
