# frozen_string_literal: true

class NewsletterMailer < ApplicationMailer
  include Templatable
  EmailRender = Struct.new(:subject, :content)

  def newsletter_email
    set_unsubscribe_token
    attach_attachments!
    template_mail(params[:member],
      from: params[:from],
      to: params[:to],
      stream: "broadcast",
      tag: params[:tag],
      headers: {
        "List-Unsubscribe-Post" => "List-Unsubscribe=One-Click",
        "List-Unsubscribe" => "<#{members_unsubscribe_newsletter_post_url}>"
      },
      **prepared_data)
  end

  def render_newsletter_email
    render_template(params[:member], **prepared_data) do |subject, content|
      EmailRender.new(subject, content)
    end
  end

  private

  def set_unsubscribe_token
    return unless params[:to]

    @unsubscribe_token = Newsletter::Audience.encrypt_email(params[:to])
  end

  def members_unsubscribe_newsletter_post_url
    helper = Rails.application.routes.url_helpers
    helper.members_unsubscribe_newsletter_post_url(
      host: Current.org.members_url,
      token: @unsubscribe_token)
  end

  def attach_attachments!
    return unless params[:attachments].present?

    params[:attachments].map(&:file).each { |file|
      filename =
        ActiveSupport::Inflector.transliterate(file.filename.to_s.gsub(/"/, "'"))
      attachments[filename] = {
        mime_type: file.content_type,
        content: file.download
      }
    }
  end

  def prepared_data
    member = params[:member]
    membership = params[:membership]

    # Scope to the imminent delivery window (next delivery date through end
    # of that week) so we don't accidentally pull baskets far in the future.
    # Within that window, find the member's first basket regardless of state,
    # then expose it only when deliverable (active + filled).
    if (next_date = Delivery.coming.pick(:date))
      date_range = next_date..next_date.end_of_week
      next_coming_basket = params[:basket] || member.baskets.between(date_range).first
      if next_coming_basket
        basket = next_coming_basket if next_coming_basket.deliverable?
        membership ||= next_coming_basket.membership
      else
        membership ||= member.memberships.overlaps(date_range).first
      end
    end

    today = I18n.with_locale(member.language) do
      params[:today] || I18n.l(Date.current)
    end
    if contents = params.delete(:template_contents)
      params[:template] = Newsletter::Template.new(contents: contents, no_preview: true)
    end
    if signature = params.delete(:signature)
      @signature = signature
    end
    {
      "today" => today,
      "subject" => params[:subject],
      "member" => Liquid::MemberDrop.new(member, email: params[:to]),
      "membership" => membership ? Liquid::MembershipDrop.new(membership) : nil,
      "basket" => basket ? Liquid::BasketDrop.new(basket) : nil,
      "future_activities" => Activity.available.first(10).map { |a|
        Liquid::ActivityDrop.new(a)
      },
      "coming_activity_participations" => member.activity_participations.coming.includes(:activity).merge(Activity.ordered(:asc)).map { |p|
        Liquid::ActivityParticipationDrop.new(p)
      }
    }
  end
end
