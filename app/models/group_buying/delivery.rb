module GroupBuying
  class Delivery < ActiveRecord::Base
    self.table_name = 'group_buying_deliveries'

    include HasFiscalYearScopes
    include HasTranslatedDescription

    has_many :orders, class_name: 'GroupBuying::Order'
    has_many :orders_without_canceled,
      -> { all_without_canceled },
      class_name: 'GroupBuying::Order'
    has_many :order_items,
      class_name: 'GroupBuying::OrderItem',
      through: :orders_without_canceled,
      source: :items

    scope :past, -> { where('date < ?', Date.current) }
    scope :coming, -> { where('date >= ?', Date.current) }
    scope :between, ->(range) { where(date: range) }
    scope :depot_eq, ->(depot_id) { where('? = ANY(depot_ids)', depot_id) }

    def self.ransackable_scopes(_auth_object = nil)
      super + %i[depot_eq]
    end

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
      "#{model_name.human} #{title}"
    end

    def title
      "##{id} – #{I18n.l date}"
    end

    def orderable?
      orderable_until >= Date.today
    end

    def depot_ids=(array)
      super array.map(&:presence).compact
    end

    def can_access?(member)
      return true if depot_ids.empty?

      member.next_basket && depot_ids.include?(member.next_basket.depot_id)
    end

    def can_destroy?
      orders.none?
    end
  end
end
