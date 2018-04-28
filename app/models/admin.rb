class Admin < ActiveRecord::Base
  include HasLanguage

  NOTIFICATIONS = %w[new_inscription]
  RIGHTS = %w[superadmin admin standard readonly none]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

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
end
