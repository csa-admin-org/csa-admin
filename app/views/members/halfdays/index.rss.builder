xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title "#{halfdays_human_name} à venir"
    xml.link members_halfdays_url

    @halfdays.each do |halfday|
      xml.item do
        xml.title halfday_label(halfday, date: true, description: false)
        xml.description halfday_label(halfday, date: true, description: true)
        xml.pubDate halfday.created_at.to_s(:rfc822)
        xml.guid halfday.cache_key
      end
    end
    if @halfdays.empty?
      xml.item do
        xml.title "Aucune #{halfday_human_name} à venir pour le moment."
      end
    end
  end
end
