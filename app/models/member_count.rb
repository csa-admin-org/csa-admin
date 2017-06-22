class MemberCount
  SCOPES = %i[pending waiting trial active support inactive]

  def self.all
    cache_key = [
      name,
      Member.maximum(:updated_at),
      Membership.maximum(:updated_at),
      Date.today
    ]
    Rails.cache.fetch cache_key do
      SCOPES.map { |scope| new(scope) }
    end
  end

  attr_reader :scope

  def initialize(scope)
    @scope = scope
    # eager load for the cache
    count
    count_precision
    count_small_basket
    count_big_basket
  end

  def title
    I18n.t("member.status.#{scope}")
  end

  def count
    @count ||= Member.send(scope).count
  end

  def count_precision
    @count_precision ||=
      case scope
      when :active
        sub_count = Member.active.where(salary_basket: true).count
        "(#{sub_count} panier-salaire) "
      when :inactive then
        sub_count = Member.inactive.joins(:memberships).merge(Membership.future).count
        "(#{sub_count} futur actif) "
      end
  end

  def count_small_basket
    return if scope == :support
    @count_small_basket ||= members.count { |m| m.basket&.small? }
  end

  def count_big_basket
    return if scope == :support
    @count_big_basket ||= members.count { |m| m.basket&.big? }
  end

  private

  def members
    @members ||=
      Member.send(scope).includes(
        :waiting_basket,
        current_membership: :basket,
        future_membership: :basket).to_a
  end
end
