class Admin < ActiveRecord::Base
  UnsupportedDeviceNotification = Class.new(StandardError)

  include HasLanguage
  include HasSessions

  acts_as_paranoid

  RIGHTS = %w[superadmin admin standard readonly none]
  NOTIFICATION_TEMPLATES = {
    new_inscription: :admin_member_new,
    invoice_overpaid: :admin_invoice_overpaid,
    new_absence: :admin_absence_new
  }

  scope :notification, ->(notification) { where('? = ANY (notifications)', notification) }

  validates :name, presence: true
  validates :rights, inclusion: { in: RIGHTS }
  validates :email, presence: true, uniqueness: true, format: /\A.+\@.+\..+\z/

  def self.notify!(notification, object, skip: [])
    template = NOTIFICATION_TEMPLATES[notification.to_sym]
    Admin.notification(notification).where.not(id: skip).find_each do |admin|
      Email.deliver_later(template, admin, object)
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
