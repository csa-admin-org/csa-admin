require 'postmark_wrapper'

class EmailSuppression < ApplicationRecord
  STREAM_IDS = %w[outbound]
  REASONS = %w[HardBounce SpamComplaint ManualSuppression Forgotten]
  ORIGINS = %w[Recipient Customer Admin Sync]

  scope :active, -> { where(unsuppressed_at: nil) }
  scope :outbound, -> { where(stream_id: 'outbound') }
  scope :mailchimp, -> { where(stream_id: 'mailchimp') }
  scope :unsuppressable, -> { where(reason: 'HardBounce', origin: 'Recipient') }

  validates :email, presence: true
  validates :reason, inclusion: { in: REASONS }
  validates :origin, inclusion: { in: ORIGINS }

  after_create_commit :notify_admins!

  def self.sync_postmark!(options = {})
    STREAM_IDS.each do |stream_id|
      PostmarkWrapper.dump_suppressions(stream_id, options).each do |suppression|
        find_or_create_by!(
          stream_id: stream_id,
          email: suppression[:email_address],
          reason: suppression[:suppression_reason],
          origin: suppression[:origin],
          created_at: suppression[:created_at])
      end
    end
  end

  def self.unsuppress!(email)
    suppressions = outbound.unsuppressable.where(email: email)
    if suppressions.any?
      PostmarkWrapper.delete_suppressions('outbound', email)
      suppressions.each(&:unsuppress!)
    end
  end

  def unsuppress!
    touch(:unsuppressed_at)
  end

  def owners
    owners = []
    owners += Admin.with_email(email)
    owners += Member.with_email(email)
    owners += Depot.with_email(email)
    owners
  end

  def mailchimp?
    stream_id == 'mailchimp'
  end

  private

  def notify_admins!
    return if mailchimp?

    Admin.notify!(:new_email_suppression, email_suppression: self)
  end
end
