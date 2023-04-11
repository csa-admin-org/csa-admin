module NewslettersHelper
  def newsletter_audience_collection
    Newsletter::Audience.segments.map { |key, segments|
      [
        Newsletter::Audience.segment_name(key),
        segments.map { |s| [s.name, s.id] }
      ]
    }.to_h
  end

  def ellipsisize(email)
    return unless email

    email.split('@').map { |part|
      case part.length
      when 0..5
        part.gsub(%r{(.).+(.)}, '\1...\2')
      when 5..8
        part.gsub(%r{(.{2}).{2,}(.{2})}, '\1...\2')
      else
        part.gsub(%r{(.{3}).{3,}(.{3})}, '\1...\2')
      end
    }.join('@')
  end
end
