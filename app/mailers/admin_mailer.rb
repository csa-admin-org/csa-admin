class AdminMailer < ApplicationMailer
  def invitation_email
    admin = params[:admin]
    I18n.with_locale(admin.language) do
      content = liquid_template.render(
        'acp' => Liquid::ACPDrop.new(Current.acp),
        'admin' => Liquid::AdminDrop.new(admin),
        'action_url' => params[:action_url])
      content_mail(content,
        to: admin.email,
        subject: t('.subject', acp: Current.acp.name))
    end
  end
end
