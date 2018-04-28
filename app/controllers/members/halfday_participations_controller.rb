class Members::HalfdayParticipationsController < Members::ApplicationController
  # POST /:member_id/halfday_participations
  def create
    @halfday_participation = current_member.halfday_participations.new(protected_params)
    respond_to do |format|
      if @halfday_participation.save
        flash[:notice] = t('.flash.notice')
        format.html { redirect_to [:members, current_member] }
      else
        format.html { render 'members/members/show' }
      end
    end
  end

  # DELETE /:member_id/halfday_participations/:id
  def destroy
    participation = current_member.halfday_participations.find(params[:id])
    participation.destroy if participation.destroyable?

    redirect_to [:members, current_member]
  end

  private

  def protected_params
    params
      .require(:halfday_participation)
      .permit(%i[halfday_id participants_count carpooling carpooling_phone])
  end
end
