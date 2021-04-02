require 'postmark_wrapper'

class EmailSuppression < ApplicationRecord
  acts_as_paranoid

  STREAM_IDS = %w[outbound mailchimp]
  REASONS = %w[HardBounce SpamComplaint ManualSuppression Forgotten]
  ORIGINS = %w[Recipient Customer Admin Sync]

  scope :outbound, -> { where(stream_id: 'outbound') }
  scope :mailchimp, -> { where(stream_id: 'mailchimp') }
  scope :deletable, -> { where(reason: 'HardBounce', origin: 'Recipient') }

  validates :email, presence: true
  validates :reason, inclusion: { in: REASONS }
  validates :origin, inclusion: { in: ORIGINS }

  after_create_commit :notify_admins!

  def self.sync(options = {})
    STREAM_IDS.each do |stream_id|
      PostmarkWrapper.dump_suppressions(stream_id, options).each do |suppression|
        with_deleted.find_or_create_by!(
          stream_id: stream_id,
          email: suppression[:email_address],
          reason: suppression[:suppression_reason],
          origin: suppression[:origin],
          created_at: suppression[:created_at])
      end
    end
  end

  def self.unsuppress!(email)
    suppressions = outbound.deletable.where(email: email)
    if suppressions.any?
      PostmarkWrapper.delete_suppressions('outbound', email)
      suppressions.each(&:destroy)
    end
  end

  def owners
    owners = []
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
