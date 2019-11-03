module GroupBuying
  class Delivery < ActiveRecord::Base
    self.table_name = 'group_buying_deliveries'

    include HasFiscalYearScopes
    include HasTranslatedDescription

    scope :past, -> { where('date < ?', Date.current) }
    scope :coming, -> { where('date >= ?', Date.current) }
    scope :between, ->(range) { where(date: range) }

    validates :date,
      presence: true,
      date: { after: proc { Date.today } }
    validates :orderable_until,
      presence: true,
      date: { before_or_equal_to: :date }

    def can_destroy?
      true
    end
  end
end
