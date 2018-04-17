class Members::ApplicationController < ApplicationController
  layout 'members'
  before_action :authenticate_member!
  before_action :set_locale

  private

  def authenticate_member!
    @member = Member.find_by(token: params[:member_id] || params[:id])
    redirect_to members_member_token_path unless @member
  end

  def set_locale
    I18n.locale = 'fr'
  end
end
