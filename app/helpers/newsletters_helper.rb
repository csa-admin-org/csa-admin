# frozen_string_literal: true

module NewslettersHelper
  def display_newsletter?
    Newsletter.any?
  end

  def newsletter_unsubscribed?
    EmailSuppression
      .unsuppressable
      .where(email: current_session.email)
      .broadcast
      .any?
  end

  def newsletter_audience_collection(newsletter)
    Newsletter::Audience.segments.map { |key, segments|
      name = Newsletter::Audience.segment_name(key)
      if newsletter.audience? && newsletter.audience_segment.key == key
        segments << newsletter.audience_segment
      end
      [
        name,
        segments.map { |s| [ s.name, s.id ] }.uniq
      ]
    }.to_h
  end

  def ellipsisize(email)
    return unless email

    email.split("@").map { |part|
      case part.length
      when 0..5
        part.gsub(%r{(.).+(.)}, '\1...\2')
      when 5..8
        part.gsub(%r{(.{2}).{2,}(.{2})}, '\1...\2')
      else
        part.gsub(%r{(.{3}).{3,}(.{3})}, '\1...\2')
      end
    }.join("@")
  end
end
