module ActivitiesHelper
  def activity_human_name
    I18n.t("activities.#{Current.acp.activity_i18n_scope}.one")
  end

  def activities_human_name
    I18n.t("activities.#{Current.acp.activity_i18n_scope}.other")
  end

  def t_activity(key, *options)
    t(activity_scoped_attribute(key), *options)
  end

  def activity_scoped_attribute(attr)
    "#{attr}/#{Current.acp.activity_i18n_scope}".to_sym
  end

  def activity_label(activity, date: false, date_format: :medium, description: true)
    labels = [
      activity.period,
      display_activity(activity, description: description),
      display_place(activity)
    ]
    labels.insert(0, l(activity.date, format: date_format).capitalize) if date
    labels.join(', ')
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
      activity.title +
        content_tag(:span, class: 'tooltip-toggle', data: { tooltip: activity.description }) {
          inline_svg 'info_circle.svg', size: '16px'
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
