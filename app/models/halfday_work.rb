class HalfdayWork < ActiveRecord::Base
  belongs_to :member
  belongs_to :validator, class: 'Admin'

  scope :validated, ->{ where.not(validated_at: nil) }
  scope :coming, ->{ where(validated_at: nil).where('date >= ?', Date.today) }

  validates :member_id, presence: true
  validates :period, inclusion: { in: %w[am pm] }
  validate :date_cannot_be_in_the_past, on: :create

  private

  def date_cannot_be_in_the_past
    if date < Date.today
      errors.add(:date, "can't be in the past")
    end
  end
end
