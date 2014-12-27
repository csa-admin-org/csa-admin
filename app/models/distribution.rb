class Distribution < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  def display_name
    "#{name} (#{city})"
  end
end
