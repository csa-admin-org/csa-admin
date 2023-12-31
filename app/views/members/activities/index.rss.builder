xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title t_activity("members.activity_participations.index.coming_activity_participations")
    xml.link members_activities_url

    limit = @activities.size == (@limit + 1) ? @limit + 1 : @limit

    @activities.first(limit).each do |activity|
      xml.item do
        xml.title activity_label(activity, date: true, date_format: :long, description: false)
        xml.description activity_label(activity, date: true, date_format: :long, description: true)
        xml.pubDate activity.created_at.to_fs(:rfc822)
        xml.guid activity.cache_key
      end
    end
    if @activities.size > limit
      xml.item do
        xml.title t("members.activity_participations.index.extra_coming_activity_participations",
          count: @activities.size - limit,
          last_date: l(@activities.last.date, format: :long))
      end
    end
    if @activities.empty?
      xml.item do
        xml.title t_activity("members.activity_participations.index.no_coming_activity_participations")
      end
    end
  end
end
