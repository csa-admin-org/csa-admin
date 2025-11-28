# frozen_string_literal: true

module CalendarsHelper
  def calendar_webcal_url
    members_calendar_url(
      token: current_member.generate_token_for(:calendar),
      protocol: "webcal")
  end

  def basket_calendar_description(basket)
    lines = []
    lines << "#{Basket.model_name.human}: #{basket.basket_description(public_name: true)}"
    if basket.baskets_basket_complements.any?
      lines << "#{MembersBasketComplement.model_name.human(count: 2)}: #{basket.complements_description(public_name: true)}"
    end
    lines << "#{Depot.model_name.human}: #{basket.depot.name}"
    lines.join("\n")
  end

  def activity_participation_admin_calendar_description(activity_participation)
    lines = []
    lines << "#{ActivityParticipation.human_attribute_name(:participants_count)}: #{activity_participation.participants_count}"
    if activity_participation.activity.description?
      lines << ""
      lines << activity_participation.activity.description
    end

    if activity_participation.carpooling_participations.any?
      lines << ""
      lines << t("members.activity_participations.activity_participation.carpooling") + ":"
      activity_participation.carpooling_participations.each do |participation|
        lines << "- #{participation.carpooling_phone}#{" (#{participation.carpooling_city})" if participation.carpooling_city?}"
      end
    end

    lines << ""
    lines << members_activity_participations_url

    lines.join("\n")
  end

  def activity_participation_admin_calendar_summary(activity_participation)
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
