class Distribution < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships

  default_scope { order(:name) }
  validates :name, presence: true

  def display_name
    @display_name ||= begin
      str = name
      str << " (#{city})" if city?
      str
    end
  end
end
