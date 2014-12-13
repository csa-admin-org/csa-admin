class Members::HalfdayWorksController < Members::ApplicationController
  # POST /:member_id/halfday_works
  def create
    @halfday_work = @member.halfday_works.new(halfday_work_params)
    respond_to do |format|
      if @halfday_work.save
        flash[:notice] = 'Merci pour votre inscription!'
        format.html { redirect_to [:members, @member] }
      else
        format.html { render 'members/members/show' }
      end
    end
  end

  # DELETE /:member_id/halfday_works/:id
  def destroy
    @member.halfday_works.destroy(params[:id])
    redirect_to [:members, @member]
  end

  private

  def halfday_work_params
    params
      .require(:halfday_work)
      .permit(%i[date period_am period_pm participants_count])
  end
end
