class Admin < ActiveRecord::Base
  UnsupportedDeviceNotification = Class.new(StandardError)

  include HasLanguage
  include HasSessions

  acts_as_paranoid

  RIGHTS = %w[superadmin admin standard readonly none]

  scope :notification, ->(notification) { where('? = ANY (notifications)', notification) }

  validates :name, presence: true
  validates :rights, inclusion: { in: RIGHTS }
  validates :email, presence: true, uniqueness: true, format: /\A.+\@.+\..+\z/

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
    all = %w[new_inscription invoice_overpaid]
    all << 'new_absence' if Current.acp.feature?('absence')
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
