# frozen_string_literal: true

class SEPAMandateMailer < ApplicationMailer
  include Templatable

  before_action :set_context

  def confirmation_email
    attach_pdf!
    template_mail(@member,
      "member" => Liquid::MemberDrop.new(@member),
      "sepa_mandate" => Liquid::SEPAMandateDrop.new(@mandate))
  end

  private

  def set_context
    @mandate = params[:sepa_mandate]
    @member = @mandate.member
  end

  def attach_pdf!
    return unless @mandate&.pdf&.attached?

    attachments[@mandate.pdf.filename.to_s] = {
      mime_type: "application/pdf",
      content: @mandate.pdf.download
    }
  end
end
