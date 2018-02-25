class GribouilleMailer < ApplicationMailer
  layout false

  def basket(gribouille, member, email)
    @gribouille = gribouille
    @member = member

    Gribouille::ATTACHMENTS_NUMBER.times.each do |i|
      if attachment = @gribouille.attachments[i]
        attachments[attachment.filename.to_s] = {
          mime_type: attachment.content_type,
          content: attachment.download
        }
      end
    end

    mail \
      to: email,
      subject: "Gribouille du #{l gribouille.delivery.date, format: :short}"
  end
end
