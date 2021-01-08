require 'postmark_wrapper'

class EmailSuppression < ApplicationRecord
  acts_as_paranoid

  STREAM_IDS = %w[outbound]
  REASONS = %w[HardBounce SpamComplaint ManualSuppression]
  ORIGINS = %w[Recipient Customer Admin]

  scope :outbound, -> { where(stream_id: 'outbound') }
  scope :deletable, -> { where(reason: 'HardBounce', origin: 'Recipient') }

  validates :email, presence: true
  validates :reason, inclusion: { in: REASONS }
  validates :origin, inclusion: { in: ORIGINS }

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
end
