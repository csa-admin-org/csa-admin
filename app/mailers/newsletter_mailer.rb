class NewsletterMailer < ApplicationMailer
  include Templatable
  EmailRender = Struct.new(:subject, :content)

  def newsletter_email
    template_mail(params[:member],
      to: params[:to],
      stream: 'broadcast',
      **prepared_data)
  end

  # Only used by Newsletter::Delivery to persist the rendered email
  def render_newsletter_email
    render_template(params[:member], **prepared_data) do |subject, content|
      EmailRender.new(subject, content)
    end
  end

  private

  def prepared_data
    member = params[:member]
    membership = member.current_or_future_membership
    basket = membership&.next_basket
    today = I18n.with_locale(member.language) do
      params[:today] || I18n.l(Date.today)
    end
    if contents = params.delete(:template_contents)
      params[:template] = Newsletter::Template.new(contents: contents, no_preview: true)
    end
    if params[:to]
      @unsubscribe_token = Newsletter::Audience.encrypt_email(params[:to])
    end
    {
      'today' => today,
      'subject' => params[:subject],
      'member' => Liquid::MemberDrop.new(member, email: params[:to]),
      'membership' => Liquid::MembershipDrop.new(membership),
      'basket' => Liquid::BasketDrop.new(basket),
      'future_activities' => Activity.available.first(10).map { |a|
        Liquid::ActivityDrop.new(a)
      },
      'coming_activity_participations' => member.activity_participations.coming.includes(:activity).merge(Activity.ordered(:asc)).map { |p|
        Liquid::ActivityParticipationDrop.new(p)
      }
    }
  end
end
