xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title t_halfday('.coming_halfdays')
    xml.link members_halfdays_url

    limit = @halfdays.size == (@limit + 1) ? @limit + 1 : @limit

    @halfdays.first(limit).each do |halfday|
      xml.item do
        xml.title halfday_label(halfday, date: true, date_format: :long, description: false)
        xml.description halfday_label(halfday, date: true, date_format: :long, description: true)
        xml.pubDate halfday.created_at.to_s(:rfc822)
        xml.guid halfday.cache_key
      end
    end
    if @halfdays.size > limit
      xml.item do
        xml.title t('.extra_coming_halfdays',
          count: @halfdays.size - limit,
          last_date: l(@halfdays.last.date, format: :long))
      end
    end
    if @halfdays.empty?
      xml.item do
        xml.title t_halfday('.no_coming_halfdays')
      end
    end
  end
end
