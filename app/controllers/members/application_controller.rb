class Members::ApplicationController < ApplicationController
  layout 'members'
  before_action :authenticate_member!
  before_action :set_locale

  private

  def authenticate_member!
    @current_member = Member.find_by(token: params[:member_id] || params[:id])
    redirect_to members_member_token_path unless @current_member
  end

  def current_member
    @current_member
  end
  helper_method :current_member

  def set_locale
    I18n.locale = params[:locale] ||
      current_member&.language ||
      I18n.default_locale
  end
end
