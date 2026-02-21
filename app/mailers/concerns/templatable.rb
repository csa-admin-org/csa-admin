# frozen_string_literal: true

module Templatable
  extend ActiveSupport::Concern

  private

  def template_mail(member, from: nil, to: nil, stream: "outbound", tag: nil, headers: {}, **data)
    tag ||= params[:template]&.tag
    render_template(member, **data) do |subject, content|
      content_mail(content, **{
        from: from,
        to: to || member.active_emails,
        subject: sanitize_html(subject),
        message_stream: stream,
        tag: tag
      }.merge(headers).compact)
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
    @data["organization"] = Liquid::OrganizationDrop.new(Current.org)
    @data.merge!(@template.liquid_data_preview) if @template.liquid_data_preview
    @data["subject"] = data["subject"] || @data["subject"] || @template.subject
    set_template_content_blocks_data
  end

  def set_template_content_blocks_data
    return unless blocks = params.delete(:blocks)

    blocks.each do |b|
      content = b.content_as_plain_text.present? ? b.content : ""
      @data[b.data_name] = Liquid::Template.parse(content).render(**@data)
    end
  end

  def render_subjet
    Liquid::Template.parse(@data["subject"]).render(**@data)
  end

  def render_content
    Liquid::Template.parse(@template.content).render(**@data)
  end

  def sanitize_html(string)
    ActionView::Base.full_sanitizer.sanitize(string)
  end
end
