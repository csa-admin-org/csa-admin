class Billing
  def self.all
    billings = Membership.all
    billings.concat(Support.all)
    billings
    billings.map! do |billing|
      {
        member: billing.member,
        price: billing.price,
        details: billing.details
      }
    end
    billings = billings.group_by { |b| b[:member] }
    billings.each_with_object([]) do |(member, billings), a|
      a << OpenStruct.new(
        member_id: member.id,
        member_name: member.name,
        member_address: member.address,
        member_zip: member.zip,
        member_city: member.city,
        member_billing_interval: member.billing_interval,
        price: billings.sum { |b| b[:price] },
        details: billings.map { |b| b[:details] }.join(' / ')
      )
    end
  end

  def self.all_for_xls
    all.map do |b|
      {
        membre: "##{b.member_id}",
        nom: b.member_name,
        adresse: b.member_address,
        zip: b.member_zip,
        ville: b.member_city,
        paiement: I18n.t("member.billing_interval.#{b.member_billing_interval}"),
        montant_sfr: b.price,
        details: b.details
      }
    end
  end

  def self.total_price(type = nil)
    case type
    when 'Abondance', 'Eveil'
      Membership.all.select { |m| m.basket.name == type }.sum(&:price)
    when 'Soutien'
      Support.all.sum(&:price)
    else
      all.sum(&:price)
    end
  end

  class Membership
    attr :membership

    def self.all
      year = Date.today.year
      memberships = ::Membership.during_year(year).includes(:member).map do |membership|
        next if membership.member.trial? || membership.billing_member.salary_basket?
        new(membership)
      end.compact
      memberships.reject { |m| m.price == 0 }
    end

    def initialize(membership)
      @membership = membership
    end

    def member
      membership.billing_member
    end

    def price
      (membership.deliveries_count * membership.total_basket_price)
    end

    def details
      str = "Abo ##{membership.id} #{basket.name}"
      str << " (#{I18n.l membership.started_on}-#{I18n.l membership.ended_on}"
      str << ", #{membership.member.name}" if membership.billing_member_id?
      str << "): #{membership.deliveries_count} * "
      if membership.halfday_works_basket_price > 0 || membership.distribution_basket_price > 0
        str << "(#{membership.basket_price}"
        str << " + #{membership.halfday_works_basket_price}" if membership.halfday_works_basket_price > 0
        str << " + #{membership.distribution_basket_price}" if membership.distribution_basket_price > 0
        str << ')'
      else
        str << membership.basket_price.to_s
      end
      str << " = #{ActionView::Base.new.number_to_currency price}"
    end

    def basket
      membership.basket
    end
  end

  class Support
    SUPPORT_PRICE = 30

    attr :member

    def self.all
      Member.support.map { |member| new(member) }
    end

    def initialize(member)
      @member = member
    end

    def price
      SUPPORT_PRICE
    end

    def details
      "Soutien: #{ActionView::Base.new.number_to_currency price}"
    end
  end
end
