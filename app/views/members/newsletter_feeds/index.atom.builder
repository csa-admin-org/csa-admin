# frozen_string_literal: true

xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  feed_params = { template_id: @template.id }
  feed_params[:locale] = @locale if @locale != Current.org.default_locale
  feed_url = members_newsletter_feed_url(**feed_params)
  updated_at = @publications.map(&:updated_at).max || @template.updated_at

  xml.title @template.title(@locale)
  xml.id feed_url
  xml.link rel: "self", type: "application/atom+xml", href: feed_url
  xml.updated updated_at.xmlschema
  xml.subtitle t("members.newsletter_feeds.index.subtitle",
    organization: Current.org.name,
    limit: Newsletter::Publication::FEED_LIMIT)
  xml.author do
    xml.name Current.org.name
  end

  if Current.org.languages.many?
    Current.org.languages.each do |locale|
      alternate_params = { template_id: @template.id }
      alternate_params[:locale] = locale if locale != Current.org.default_locale
      xml.link(
        rel: "alternate",
        type: "application/atom+xml",
        hreflang: locale,
        href: members_newsletter_feed_url(**alternate_params))
    end
  end

  @publications.each do |publication|
    xml.entry do
      xml.id publication.atom_id
      xml.title publication.title(@locale)
      xml.published publication.published_at.xmlschema
      xml.updated publication.updated_at.xmlschema
      xml.summary publication.summary(@locale) if publication.summary(@locale).present?
      xml.content publication.content_html(
        locale: @locale,
        url_options: active_storage_url_options), type: "html"
      publication.attachments.each do |attachment|
        href = publication.attachment_url(attachment, url_options: active_storage_url_options)
        next if href.blank?

        xml.link(
          rel: "enclosure",
          type: attachment["content_type"].presence || "application/octet-stream",
          title: attachment["filename"],
          length: attachment["byte_size"],
          href: href)
      end
      xml.tag!("csa:content_digest", publication.content_digest,
        "xmlns:csa" => "https://csa-admin.org/atom")
    end
  end
end
