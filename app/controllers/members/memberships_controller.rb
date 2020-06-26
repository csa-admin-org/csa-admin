class Members::MembershipsController < Members::BaseController
  # GET /membership
  def show
    @membership = current_member.current_or_future_membership
    redirect_to members_member_path unless @membership
  end
end
