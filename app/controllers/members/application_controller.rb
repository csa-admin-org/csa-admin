class Members::ApplicationController < ApplicationController
  layout 'members'
  before_action :authenticate_member!

  private

  def authenticate_member!
    @member = Member.find_by(token: params[:member_id] || params[:id])
    redirect_to edit_member_token_path unless @member
  end
end
