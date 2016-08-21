class GribouilleMailer < ApplicationMailer
  helper :halfday_works
  layout false

  def basket(gribouille, member, email)
    @gribouille = gribouille
    @member = member
    mail \
      to: email,
      subject: "Gribouille du #{l gribouille.delivery.date, format: :short}"
  end
end
