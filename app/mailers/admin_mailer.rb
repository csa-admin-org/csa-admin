class AdminMailer < ApplicationMailer
  layout false

  def new_inscription(member)
    @member = member
    mail(
      to: 'chantalgraef@gmail.com',
      cc: %w[
        bichseld@gmail.com
        olalabambel@gmail.com
        raphael.coquoz@bluewin.ch
        amandinebouille01@gmail.com
        thibaud@thibaud.gg
        sacha.dubois@hotmail.ch
        tristan@amez-droz.org
      ],
      subject: "#{Current.acp.name}: nouvelle inscription à valider"
    )
  end
end
