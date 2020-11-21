class MemberMailer < ApplicationMailer
  def activated_email
    member = params[:member]
    membership = params[:membership]
    template_mail(member,
      'member' => Liquid::MemberDrop.new(member),
      'membership' => Liquid::MembershipDrop.new(membership))
  end

  private

  def template_mail(member, **data)
    template = params[:template]
    I18n.with_locale(member.language) do
      data = template.liquid_data_preview if template.liquid_data_preview
      subject = Liquid::Template.parse(template.subject).render(**data)
      content = Liquid::Template.parse(template.content).render(**data)
      content_mail(content,
        to: member.emails_array,
        subject: subject)
    end
  end
end
