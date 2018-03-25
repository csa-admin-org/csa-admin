module Newsletter
  def self.sync_list
    return unless mailchimp_credentials = Current.acp.credentials(:mailchimp)

    mailchimp = Newsletter::MailChimp.new(mailchimp_credentials)
    mailchimp.upsert_merge_fields
    mailchimp.upsert_members(Member.all)
    mailchimp.remove_deleted_members(Member.all)
  end
end
