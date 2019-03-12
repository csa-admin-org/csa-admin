class Stats::MembersStat < Stats::BaseStat
  def self.all
    [new(Current.fy_year)]
  end

  def data
    {
      t('member.waiting') => (
        Member.pending.count +
        Member.waiting.count
      ),
      t('member.memberships.trial') => Membership.trial.count,
      t('member.memberships.ongoing') => Membership.ongoing.count,
      t('member.memberships.future') => Membership.future.count,
      t('member.support') => Member.support.count
    }.sort_by { |_k, v| -1 * v }.to_h
  end

  private

  def t(key)
    I18n.t("states.#{key}").capitalize
  end
end
