module Templatable
  extend ActiveSupport::Concern

  private

  def template_mail(member, to: nil, **data)
    template = params[:template]
    I18n.with_locale(member.language) do
      data['acp'] = Liquid::ACPDrop.new(Current.acp)
      data = template.liquid_data_preview if template.liquid_data_preview
      subject = Liquid::Template.parse(template.subject).render(**data)
      content = Liquid::Template.parse(template.content).render(**data)
      content_mail(content,
        to: to || member.emails_array,
        subject: subject)
    end
  end
end
