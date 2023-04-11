class Members::InfosController < Members::BaseController
  before_action :ensure_info_presence

  # GET /info
  def show
  end

  private

  def ensure_info_presence
    unless Current.acp.member_information_text?
      redirect_to members_member_path
    end
  end
end
