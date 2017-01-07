class GribouilleMailer < ApplicationMailer
  helper :halfdays
  helper :application
  layout false

  def basket(gribouille, member, email)
    @gribouille = gribouille
    @member = member

    if @gribouille.attachment?
      attachments[@gribouille.attachment_name] = {
        mime_type: @gribouille.attachment_mime_type,
        content: @gribouille.attachment.file.read
      }
    end

    mail \
      to: email,
      subject: "Gribouille du #{l gribouille.delivery.date, format: :short}"
  end
end
