class NewsletterMailerPreview < ActionMailer::Preview
  include SharedDataPreview

  def newsletter_email
    params.merge!(newsletter_email_params)
    NewsletterMailer.with(params).newsletter_email
  end

  private

  def newsletter_email_params
    {
      today: I18n.l(Date.today),
      member: member
    }
  end
end


