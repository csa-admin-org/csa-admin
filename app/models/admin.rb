class Admin < ActiveRecord::Base
  UnsupportedDeviceNotification = Class.new(StandardError)

  include HasLanguage

  NOTIFICATIONS = %w[new_inscription new_absence]
  RIGHTS = %w[superadmin admin standard readonly none]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable

  scope :notification, ->(notification) { where('? = ANY (notifications)', notification) }

  validates :name, presence: true
  validates :rights, inclusion: { in: RIGHTS }

  def notifications=(notifications)
    super(notifications.select(&:presence).compact)
  end

  def superadmin?
    rights == 'superadmin'
  end

  def right?(right)
    RIGHTS.index(self[:rights]) <= RIGHTS.index(right)
  end

  def send_devise_notification(notification, *args)
    case notification
    when :reset_password_instructions
      Email.deliver_later(:admin_reset_password, self, args.first)
    else
      ExceptionNotifier.notify(UnsupportedDeviceNotification.new,
        notifiation: notification,
        args: args)
    end
  end
end
