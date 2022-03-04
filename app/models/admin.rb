class Admin < ApplicationRecord
  include HasSessions

  attribute :language, :string, default: -> { Current.acp.languages.first }

  belongs_to :permission
  has_many :validated_member,
    class_name: 'ActivityParticipation',
    foreign_key: :validator_id,
    dependent: :nullify
  has_many :validated_activity_participations,
    class_name: 'ActivityParticipation',
    foreign_key: :validator_id,
    dependent: :nullify

  scope :notification, ->(notification) { where('? = ANY (notifications)', notification) }
  scope :with_email, ->(email) { where('lower(email) = ?', email.downcase) }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: /\A.+\@.+\..+\z/
  validates :language, presence: true, inclusion: { in: proc { ACP.languages } }

  after_create -> { Update.mark_as_read!(self) }

  def self.notify!(notification, skip: [], **attrs)
    Admin.notification(notification).where.not(id: skip).find_each do |admin|
      attrs[:admin] = admin
      AdminMailer
        .with(**attrs)
        .send("#{notification}_email")
        .deliver_later
    end
  end

  def self.notifications
    all = %w[
      new_email_suppression
      new_inscription
      invoice_overpaid
      invoice_third_overdue_notice
    ]
    all << 'new_absence' if Current.acp.feature?('absence')
    all << 'new_group_buying_order' if Current.acp.feature?('group_buying')
    all
  end

  def notifications=(notifications)
    super(notifications.select(&:presence).compact)
  end

  def master?
    email == ENV['MASTER_ADMIN_EMAIL']
  end
end
