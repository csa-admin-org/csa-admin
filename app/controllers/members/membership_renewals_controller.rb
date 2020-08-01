class Members::MembershipRenewalsController < Members::BaseController
  before_action :redirect_renewal_decision_params!, only: :new

  # GET /membership/renewal/new
  # GET /membership/:decision
  def new
    @membership = current_member.current_year_membership
    @membership.renewal_decision = params[:decision]

    redirect_to members_member_path unless @membership&.renewal_open?
  end

  # POST /membership/renewal
  def create
    membership = current_member.current_year_membership
    case params.require(:membership).require(:renewal_decision)
    when 'cancel'
      membership.cancel!(renewal_params)
      flash[:notice] = t('.flash.canceled')
    when 'renew'
      membership.renew!(renewal_params)
      flash[:notice] = t('.flash.renewed')
    end

    redirect_to members_membership_path
  end

  private

  def redirect_renewal_decision_params!
    if decision = params.dig(:membership, :renewal_decision)
      redirect_to url_for(decision: decision)
    end
  end

  def renewal_params
    params
      .require(:membership)
      .permit(*%i[
        renewal_annual_fee
        renewal_note
        basket_size_id
        depot_id
      ], basket_complement_ids: [])
  end
end
