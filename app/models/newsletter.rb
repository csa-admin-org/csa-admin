module Newsletter
  def self.sync_list
    return if Rails.env.development?
    return unless mailchimp_credentials = Current.acp.credentials(:mailchimp)

    mailchimp = Newsletter::MailChimp.new(mailchimp_credentials)
    I18n.with_locale(Current.acp.default_locale) do
      mailchimp.upsert_merge_fields
      mailchimp.upsert_members(Member.all)
      mailchimp.unsubscribe_deleted_members(Member.all)
    end
  rescue Gibbon::MailChimpError => e
    ExceptionNotifier.notify(e)
    Sentry.capture_exception(e)
  end
end
