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

  def invoice_overpaid_email
    @admin = params[:admin]
    I18n.with_locale(@admin.language) do
      invoice = Liquid::InvoiceDrop.new(params[:invoice])
      content = liquid_template.render(
        'admin' => Liquid::AdminDrop.new(@admin),
        'member' => Liquid::MemberDrop.new(params[:member]),
        'invoice' => invoice)
      content_mail(content,
        to: @admin.email,
        subject: t('.subject', number: invoice.number))
    end
  end

  def new_absence_email
    @admin = params[:admin]
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        'admin' => Liquid::AdminDrop.new(@admin),
        'member' => Liquid::MemberDrop.new(params[:member]),
        'absence' => Liquid::AbsenceDrop.new(params[:absence]))
      content_mail(content,
        to: @admin.email,
        subject: t('.subject'))
    end
  end

  def new_inscription_email
    @admin = params[:admin]
    I18n.with_locale(@admin.language) do
      content = liquid_template.render(
        'admin' => Liquid::AdminDrop.new(@admin),
        'member' => Liquid::MemberDrop.new(params[:member]))
      content_mail(content,
        to: @admin.email,
        subject: t('.subject'))
    end
  end
end
