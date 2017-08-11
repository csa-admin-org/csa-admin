class GribouilleMailer < ApplicationMailer
  helper :halfdays
  helper :application
  layout false

  def basket(gribouille, member, email)
    @gribouille = gribouille
    @member = member

    3.times.each do |i|
      if @gribouille.send("attachment_name_#{i}?")
        attachments[@gribouille.send("attachment_name_#{i}")] = {
          mime_type: @gribouille.send("attachment_mime_type_#{i}"),
          content: @gribouille.send("attachment_#{i}").file.read
        }
      end
    end

    mail \
      to: email,
      subject: "Gribouille du #{l gribouille.delivery.date, format: :short}"
  end
end
