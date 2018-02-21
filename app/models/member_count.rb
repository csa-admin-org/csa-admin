class MemberCount
  SCOPES = %i[pending waiting trial active support inactive]

  def self.all
    SCOPES.delete(:trial) if Current.acp.trial_basket_count.zero?
    SCOPES.map { |scope| new(scope) }
  end

  attr_reader :scope

  def initialize(scope)
    @scope = scope
  end

  def title
    I18n.t("member.status.#{scope}")
  end

  def count
    Member.send(scope).count
  end

  def count_precision
    case scope
    when :active
      sub_count = Member.active.where(salary_basket: true).count
      "(#{sub_count} panier-salaire) "
    end
  end
end
