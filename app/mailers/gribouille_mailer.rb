class GribouilleMailer < ApplicationMailer
  layout false

  def basket(gribouille, email)
    @gribouille = gribouille
    mail \
      to: email,
      subject: "Gribouille du #{l gribouille.delivery.date, format: :short}"
  end
end
