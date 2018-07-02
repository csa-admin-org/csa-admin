class Members::HalfdayParticipationsController < Members::BaseController
  # POST /halfday_participations
  def create
    @halfday_participation = current_member.halfday_participations.new(protected_params)
    respond_to do |format|
      if @halfday_participation.save
        flash[:notice] = t('.flash.notice')
        format.html { redirect_to members_member_path }
      else
        format.html { render 'members/members/show' }
      end
    end
  end

  # DELETE /halfday_participations/:id
  def destroy
    participation = current_member.halfday_participations.find(params[:id])
    participation.destroy if participation.destroyable?

    redirect_to members_member_path
  end

  private

  def protected_params
    params
      .require(:halfday_participation)
      .permit(%i[halfday_id participants_count carpooling carpooling_phone])
  end
end
