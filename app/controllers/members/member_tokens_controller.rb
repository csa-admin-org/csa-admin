class Members::MemberTokensController < Members::ApplicationController
  skip_before_action :authenticate_member!

  # GET /token/recover
  def show
  end

  # POST /token/recover
  def create
    if member = Member.with_email(params[:email]).first
      I18n.locale = member.language
      Email.deliver_later(:member_login, member, params[:email])
    else
      Email.deliver_later(:member_login_help, params[:email], I18n.locale.to_s)
    end
    redirect_to members_member_token_path(locale: I18n.locale), notice: t('.flash.notice')
  end
end
