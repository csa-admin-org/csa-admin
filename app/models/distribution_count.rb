class DistributionCount
  def self.all(next_delivery)
    cache_key = [
      name,
      Membership.maximum(:updated_at),
      Date.today
    ]
    Rails.cache.fetch cache_key do
      distributions = Distribution.with_delivery_memberships(next_delivery)
      distributions.map { |dist| new(dist, next_delivery) }
    end
  end

  def initialize(distribution, next_delivery)
    @distribution = distribution
    @next_delivery = next_delivery
    # eager load for the cache
    count
    baskets_count
  end

  def title
    @distribution.name
  end

  def count
    @count ||= memberships.size
  end

  def baskets_count
    @baskets_count ||= [count_small_basket, count_big_basket].join(' / ')
  end

  def count_small_basket
    @count_small_basket ||= memberships.count { |m| m.basket.small? }
  end

  def count_big_basket
    @count_big_basket ||= memberships.count { |m| m.basket.big? }
  end

  private

  def memberships
    @memberships ||= @distribution.delivery_memberships.to_a
  end
end
