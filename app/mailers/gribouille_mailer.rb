class GribouilleMailer < ApplicationMailer
  layout false

  def basket(gribouille)
    @gribouille = gribouille
    # emails = Member.gribouille_emails
    emails = %w[
      thibaud@thibaud.gg
      thibaud@electricfeel.com
      leilapecon@gmail.com
    ]
    mail \
      bcc: emails,
      subject: "Gribouille du #{l gribouille.delivery.date, format: :short}"
  end
end
