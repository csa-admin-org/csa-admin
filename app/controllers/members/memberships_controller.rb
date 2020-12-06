class Members::MembershipsController < Members::BaseController
  # GET /membership
  def show
    @membership = current_member.current_or_future_membership
    if @membership
      @membership.renewal_decision = :renew
    else
      redirect_to members_member_path
    end
  end
end
