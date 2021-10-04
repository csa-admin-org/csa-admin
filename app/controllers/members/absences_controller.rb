class Members::AbsencesController < Members::BaseController
  before_action :ensure_absence_feature

  # GET /absences
  def index
    min = Absence.min_started_on + 1.day
    @absence = Absence.new(
      started_on: min,
      ended_on: (min + 1.day).end_of_week)
  end

  # POST /absences
  def create
    @absence = current_member.absences.new(protected_params)
    @absence.session_id = session_id

    if @absence.save
      flash[:notice] = t('.flash.notice')
      redirect_to members_absences_path
    else
      render :index, status: :unprocessable_entity
    end
  end

  # DELETE /absences/:id
  def destroy
    absence = current_member.absences.find(params[:id])
    absence.destroy

    redirect_to members_absences_path
  end

  private

  def protected_params
    params.require(:absence).permit(:started_on, :ended_on)
  end

  def ensure_absence_feature
    redirect_to members_member_path unless Current.acp.feature?('absence')
  end
end
