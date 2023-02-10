module Templatable
  extend ActiveSupport::Concern

  private

  def template_mail(member, to: nil, **data)
    render_template(member, **data) do |subject, content|
      content_mail(content,
        to: to || member.emails_array,
        subject: subject)
    end
  end

  def render_template(member, **data)
    I18n.with_locale(member.language) do
      set_data(data)
      yield render_subjet, render_content
    end
  end

  def set_data(data)
    @data = data.dup
    @template = params[:template]
    @data['acp'] = Liquid::ACPDrop.new(Current.acp)
    @data.merge!(@template.liquid_data_preview) if @template.liquid_data_preview
    @data['subject'] = data['subject'] || @data['subject'] || @template.subject
    set_template_content_blocks_data
  end

  def set_template_content_blocks_data
    return unless blocks = params.delete(:blocks)

    blocks.each do |b|
      @data[b.data_name] = Liquid::Template.parse(b.content.to_s).render(**@data)
    end
  end

  def render_subjet
    Liquid::Template.parse(@data['subject']).render(**@data)
  end

  def render_content
    Liquid::Template.parse(@template.content).render(**@data)
  end
end
