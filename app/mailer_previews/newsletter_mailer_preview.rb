class NewsletterMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def newsletter_email
    params.merge!(newsletter_email_params)
    params[:to] = "example@acp-admin.ch"
    NewsletterMailer.with(params).newsletter_email
  end

  private

  def newsletter_email_params
    data = {
      today: I18n.l(Date.today),
      member: member,
      membership: membership,
      basket: basket
    }
    if Current.acp.feature?(:activity)
      data[:future_activities] = Activity.available.first(10).each { |a|
        Liquid::ActivityDrop.new(a)
      }
      data[:coming_activity_participations] = member.activity_participations.coming.includes(:activity).merge(Activity.ordered(:asc)).each { |p|
        Liquid::ActivityParticipationDrop.new(p)
      }
    end
    data
  end
end
