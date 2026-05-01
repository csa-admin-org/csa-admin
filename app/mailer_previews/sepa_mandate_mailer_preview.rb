# frozen_string_literal: true

class SEPAMandateMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def confirmation_email
    params.merge!(confirmation_email_params)
    params[:template] ||= MailTemplate.find_by!(title: :sepa_mandate_confirmation)
    SEPAMandateMailer.with(params).confirmation_email
  end

  private

  def confirmation_email_params
    mandate = OpenStruct.new(
      umr: member.id.to_s,
      signed_on: Date.current,
      masked_iban: "DE21 •••• •••• 3210",
      member: member,
      pdf: OpenStruct.new(attached?: false))

    {
      member: member,
      sepa_mandate: mandate
    }
  end
end
