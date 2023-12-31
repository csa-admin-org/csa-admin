module ActivitiesHelper
  def display_activity?
    Current.acp.feature?("activity") && !current_member.inactive?
  end

  def activity_human_name
    I18n.t("activities.#{Current.acp.activity_i18n_scope}.one")
  end

  def activities_human_name
    I18n.t("activities.#{Current.acp.activity_i18n_scope}.other")
  end

  def t_activity(key, **options)
    t(activity_scoped_attribute(key), **options)
  end

  def activity_scoped_attribute(attr)
    "#{attr}/#{Current.acp.activity_i18n_scope}".to_sym
  end

  def activities_collection(activities, data: {})
    activities.map do |activity|
      text = content_tag(:span, class: "inline-block flex-grow #{'cursor-not-allowed text-gray-300 dark:text-gray-700' if activity.full?}") {
        content_tag(:span, class: "flex flex-col md:flex-row flex-wrap justify-start mr-2") do
          activity_label(activity).html_safe
        end
      }.concat(
        content_tag(:span, class: "flex-none ml-2 flex flex-row flex-nowrap text-gray-400 dark:text-gray-800 #{'font-semibold' if activity.full?}", title: t("activities.participant_count", count: activity.participants_count)) {
          content_tag(:span, class: "mr-1") {
            "#{activity.participants_count}/#{activity.participants_limit || '∞'}"
          }.concat(
            inline_svg_tag "members/participant.svg", class: "h-6 w-6 flex-shrink-0 fill-stroke")
        })
      [
        text,
        activity.id,
        data: {
          date: activity.date.to_s
        }.merge(data)
      ]
    end
  end

  def activity_label(activity, date: false, date_format: :medium, description: true)
    labels = [
      content_tag(:span, activity.period, class: "whitespace-nowrap"),
      content_tag(:span) {
        [
          display_activity(activity, description: description),
          display_place(activity)
        ].join(", ").html_safe
      }
    ]
    labels.insert(0, l(activity.date, format: date_format).capitalize) if date
    labels.join(content_tag(:span, ",&nbsp;".html_safe, class: "hidden md:inline whitespace-nowrap"))
  end

  def display_place(activity)
    if activity.place_url
      link_to(activity.place, activity.place_url, target: :blank)
    else
      activity.place
    end
  end

  def display_activity(activity, description: true)
    if description && activity.description
      content_tag(:span, class: "inline-block") {
        content_tag(:span, class: "flex flex-row items-center") {
          (content_tag(:span, activity.title, class: "inline-block") +
            content_tag(:span, class: "inline-block tooltip-toggle", data: { tooltip: activity.description }) {
              inline_svg_tag "members/info_circle.svg", size: "16px"
            }).html_safe
        }
      }
    else
      activity.title
    end
  end

  def activity_participation_summary(activity_participation)
    summary = activity_participation.member.name
    if activity_participation.participants_count > 1
      summary << " (#{activity_participation.participants_count})"
    end
    if activity_participation.pending? || activity_participation.rejected? || activity_participation.validated?
      summary << " [#{activity_participation.state_i18n_name}]"
    end
    summary
  end
end
