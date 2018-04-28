xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title t_halfday('.coming_halfday_participations')
    xml.link members_halfdays_url

    @halfdays.each do |halfday|
      xml.item do
        xml.title halfday_label(halfday, date: true, date_format: :long, description: false)
        xml.description halfday_label(halfday, date: true, date_format: :long, description: true)
        xml.pubDate halfday.created_at.to_s(:rfc822)
        xml.guid halfday.cache_key
      end
    end
    if @halfdays.empty?
      xml.item do
        xml.title t_halfday('.no_coming_halfday_participations')
      end
    end
  end
end
