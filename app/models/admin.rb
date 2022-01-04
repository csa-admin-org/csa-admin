class Admin < ApplicationRecord
  UnsupportedDeviceNotification = Class.new(StandardError)

  include HasSessions

  acts_as_paranoid

  RIGHTS = %w[superadmin admin standard readonly none]
  attribute :language, :string, default: -> { Current.acp.languages.first }

  scope :notification, ->(notification) { where('? = ANY (notifications)', notification) }
  scope :with_email, ->(email) { where('lower(email) = ?', email.downcase) }

  validates :name, presence: true
  validates :rights, inclusion: { in: RIGHTS }
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
    all = %w[new_email_suppression new_inscription invoice_overpaid]
    all << 'new_absence' if Current.acp.feature?('absence')
    all << 'new_group_buying_order' if Current.acp.feature?('group_buying')
    all
  end

  def notifications=(notifications)
    super(notifications.select(&:presence).compact)
  end

  def superadmin?
    rights == 'superadmin'
  end

  def right?(right)
    RIGHTS.index(self[:rights]) <= RIGHTS.index(right)
  end
end
