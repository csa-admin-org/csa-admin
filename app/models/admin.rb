class Admin < ActiveRecord::Base
  RIGHTS = %w[superadmin admin standard readonly none]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

  validates :rights, inclusion: { in: RIGHTS }

  def superadmin?
    rights == 'superadmin'
  end
end
