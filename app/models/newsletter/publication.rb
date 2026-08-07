# frozen_string_literal: true

class Newsletter
  class Publication < ApplicationRecord
    self.table_name = "newsletter_publications"

    FEED_LIMIT = 10
    ACTIVE_STORAGE_PATH = %r{(?:https?://[^/"'\s]+)?(/rails/active_storage/[^"'\s>]+)}i

    belongs_to :newsletter
    belongs_to :template,
      class_name: "Newsletter::Template",
      foreign_key: "newsletter_template_id"

    scope :active, -> { where(withdrawn_at: nil) }
    scope :withdrawn, -> { where.not(withdrawn_at: nil) }
    scope :newest_first, -> { order(published_at: :desc, id: :desc) }
    scope :for_feed, ->(template) {
      active
        .where(newsletter_template_id: template.id)
        .joins(:newsletter)
        .merge(Newsletter.sent)
        .newest_first
        .limit(FEED_LIMIT)
    }

    validates :published_at, :atom_id, :content_digest, :payload, presence: true
    validates :newsletter_id, uniqueness: true
    validates :atom_id, uniqueness: true

    def self.create_from_newsletter!(newsletter)
      payload = PublicProjection.payload_for(newsletter)
      return if payload.empty?

      attachments = attachment_payloads_for(newsletter)
      payload = payload.merge("attachments" => attachments) if attachments.any?

      published_at = newsletter.sent_at || Time.current
      create!(
        newsletter: newsletter,
        template: newsletter.template,
        published_at: published_at,
        atom_id: build_atom_id(newsletter, published_at),
        content_digest: PublicProjection.content_digest_for(payload),
        payload: payload)
    end

    def self.attachment_payloads_for(newsletter)
      newsletter.attachments.filter_map { |attachment|
        next unless attachment.file.attached?

        blob = attachment.file.blob
        {
          "filename" => blob.filename.to_s,
          "content_type" => blob.content_type.to_s,
          "byte_size" => blob.byte_size,
          "signed_id" => blob.signed_id
        }
      }
    end

    def self.build_atom_id(newsletter, published_at)
      "tag:#{Tenant.members_host},#{published_at.year}:newsletter/#{newsletter.id}"
    end

    def self.resolve_locale(locale = nil)
      requested = locale.to_s.presence
      if requested.in?(Current.org.languages)
        requested
      else
        Current.org.default_locale
      end
    end

    def withdraw!
      update!(withdrawn_at: Time.current) unless withdrawn?
    end

    def withdrawn?
      withdrawn_at?
    end

    def can_update?
      false
    end

    def can_destroy?
      false
    end

    def for_locale(locale = nil)
      locale = self.class.resolve_locale(locale)
      data = payload_for(locale)
      return data if data.present?

      payload_for(Current.org.default_locale).presence ||
        payload.values.find { |value| value.is_a?(Hash) && value["sections"].present? } ||
        {}
    end

    def title(locale = nil)
      for_locale(locale)["title"].to_s
    end

    def summary(locale = nil)
      for_locale(locale)["summary"].to_s
    end

    def sections(locale = nil)
      Array(for_locale(locale)["sections"])
    end

    def attachments
      Array(payload["attachments"]).select { |attachment|
        attachment.is_a?(Hash) && attachment["signed_id"].present?
      }
    end

    def attachment_url(attachment, url_options: {})
      blob = ActiveStorage::Blob.find_signed(attachment["signed_id"])
      return unless blob

      Rails.application.routes.url_helpers.rails_blob_url(
        blob,
        **absolute_asset_url_options(url_options))
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      nil
    end

    def locale(preferred = nil)
      resolved = self.class.resolve_locale(preferred)
      return resolved if payload_for(resolved).present?

      if payload_for(Current.org.default_locale).present?
        Current.org.default_locale
      else
        payload.keys.find { |key| payload_for(key).present? } || resolved
      end
    end

    def content_html(locale: nil, url_options: {})
      sections(locale).filter_map { |section|
        body = rewrite_active_storage_urls(section["html"].to_s, url_options)
        next if body.blank?

        section_id = ERB::Util.html_escape(section["id"])
        title = section["title"].to_s
        heading = title.present? ? %(<h2>#{ERB::Util.html_escape(title)}</h2>) : ""
        %(<section id="#{section_id}">#{heading}#{body}</section>)
      }.join("\n")
    end

    private

    def payload_for(locale)
      data = payload[locale.to_s]
      data.is_a?(Hash) ? data : nil
    end

    def rewrite_active_storage_urls(html, url_options)
      return html if html.blank?

      base = absolute_asset_origin(url_options)
      html.gsub(ACTIVE_STORAGE_PATH) do
        path = Regexp.last_match(1)
        "#{base}#{path}"
      end
    end

    def absolute_asset_origin(url_options)
      opts = absolute_asset_url_options(url_options)
      origin = "#{opts[:protocol]}://#{opts[:host]}"
      port = opts[:port]
      origin += ":#{port}" if port.present? && ![ 80, 443 ].include?(port.to_i)
      origin
    end

    def absolute_asset_url_options(url_options)
      host = url_options[:host].presence ||
        (Rails.env.local? ? Tenant.members_host : Tenant.admin_host)
      protocol = (url_options[:protocol].presence || "https").to_s.delete_suffix("://")
      port = url_options[:port]

      options = { host: host, protocol: protocol }
      options[:port] = port if port.present? && ![ 80, 443 ].include?(port.to_i)
      options
    end
  end
end
