module DashboardHelper
  def members_count
    membership_states = %i[trial ongoing future]
    membership_states.delete(:trial) unless Current.acp.trial_basket_count.positive?

    [
      %i[pending waiting active].map { |s| members_link_and_count(s) },
      membership_states.map { |s| memberships_link_and_count(s) },
      %i[support inactive].map { |s| members_link_and_count(s) }
    ].flatten.map { |h| OpenStruct.new(h) }
  end

  private

  def members_link_and_count(state)
    {
      status: link_to(
        I18n.t("states.member.#{state}").capitalize,
        members_path(scope: state)),
      count: Member.send(state).count
    }
  end

  def memberships_link_and_count(state, prefix: '&nbsp;&nbsp;- ')
    {
      status: prefix.html_safe + link_to(
        I18n.t("states.member.memberships.#{state}"),
        memberships_path(scope: state)),
      count: Membership.send(state).count
    }
  end
end
