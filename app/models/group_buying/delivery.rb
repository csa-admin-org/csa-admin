module GroupBuying
  class Delivery < ActiveRecord::Base
    self.table_name = 'group_buying_deliveries'

    include HasFiscalYearScopes
    include HasTranslatedDescription

    has_many :orders, class_name: 'GroupBuying::Order'

    scope :past, -> { where('date < ?', Date.current) }
    scope :coming, -> { where('date >= ?', Date.current) }
    scope :between, ->(range) { where(date: range) }

    validates :date,
      presence: true,
      date: { after: proc { Date.today } }
    validates :orderable_until,
      presence: true,
      date: { before_or_equal_to: :date }

    def self.next
      coming.order(:date).first
    end

    def display_name
      "##{id} – #{I18n.l date}"
    end

    def orderable?
      orderable_until >= Date.today
    end

    def can_destroy?
      orders.none?
    end
  end
end
