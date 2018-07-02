require 'bcrypt'

class Members::SessionsController < Members::BaseController
  layout 'members'
  skip_before_action :authenticate_member!

  # GET /login
  def new
    @session = Session.new
  end

  # POST /sessions
  def create
    email = params.require(:session).require(:email)
    @session = build_session(email)

    if @session.save
      url = members_session_url(@session.token)
      I18n.locale = @session.member.language
      Email.deliver_later(:member_login, @session.member, email, url)
    else
      Email.deliver_later(:member_login_help, email, I18n.locale.to_s)
    end

    redirect_to members_login_path(locale: I18n.locale), notice: t('.flash.notice')
  end

  # GET /sessions/:id
  def show
    # Make it "slow" on purpose to make brute-force attacks more of a hassle
    BCrypt::Password.create(params[:id])

    @session = Session.find_by!(token: params[:id])

    if !@session.timeout?
      cookies.encrypted.permanent[:session_id] = @session.id
      redirect_to members_member_path, notice: t('.flash.logged_in')
    elsif current_member&.id == @session.member_id
      redirect_to members_member_path, notice: t('.flash.already_logged_in')
    else
      redirect_to members_login_path, alert: t('.flash.session_timeout')
    end
  end

  # DELETE /logout
  def destroy
    cookies.delete(:session_id)
    redirect_to members_login_path, notice: t('.flash.notice')
  end

  # GET /:token
  def old_token
    Member.find_by!(token: params[:token])
    redirect_to members_login_path, alert: t('members.flash.session_expired')
  end

  private

  def build_session(email)
    session = Session.new
    session.remote_addr = request.remote_addr
    session.user_agent = request.env['HTTP_USER_AGENT'] || '-'
    session.email = email
    session
  end
end
