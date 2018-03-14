class Members::HalfdayParticipationsController < Members::ApplicationController
  # POST /:member_id/halfday_participations
  def create
    @halfday_participation = @member.halfday_participations.new(protected_params)
    respond_to do |format|
      if @halfday_participation.save
        flash[:notice] = 'Merci pour votre inscription!'
        format.html { redirect_to [:members, @member] }
      else
        format.html { render 'members/members/show' }
      end
    end
  end

  # DELETE /:member_id/halfday_participations/:id
  def destroy
    participation = @member.halfday_participations.find(params[:id])
    participation.destroy if participation.destroyable?

    redirect_to [:members, @member]
  end

  private

  def protected_params
    params
      .require(:halfday_participation)
      .permit(%i[halfday_id participants_count carpooling carpooling_phone])
  end
end
