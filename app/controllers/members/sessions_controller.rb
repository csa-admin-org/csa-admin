require 'bcrypt'

class Members::SessionsController < Members::BaseController
  layout 'members'
  skip_before_action :authenticate_member!

  # GET /login
  def new
    redirect_to members_member_path if current_member
    @session = Session.new
  end

  # POST /sessions
  def create
    email = params.require(:session).require(:email)
    @session = build_session(email)

    if @session.save
      url = members_session_url(@session.token, locale: @session.member.language)
      Email.deliver_later(:session_new, @session.member, email, url)
      redirect_to members_login_path, notice: t('sessions.flash.initiated')
    elsif @session.errors[:email].present?
      render :new
    else
      Email.deliver_later(:session_help, email, I18n.locale.to_s)
      redirect_to members_login_path, notice: t('sessions.flash.initiated')
    end
  end

  # GET /sessions/:id
  def show
    # Make it "slow" on purpose to make brute-force attacks more of a hassle
    BCrypt::Password.create(params[:id])

    @session = Session.find_by!(token: params[:id])

    if !@session.timeout?
      cookies.encrypted.permanent[:session_id] = @session.id
      redirect_to members_member_path, notice: t('sessions.flash.created')
    elsif current_member&.id == @session.member_id
      redirect_to members_member_path, notice: t('sessions.flash.already_exists')
    else
      redirect_to members_login_path, alert: t('sessions.flash.timeout')
    end
  end

  # DELETE /logout
  def destroy
    cookies.delete(:session_id)
    redirect_to members_login_path, notice: t('sessions.flash.deleted')
  end

  private

  def build_session(email)
    session = Session.new
    session.remote_addr = request.remote_addr
    session.user_agent = request.env['HTTP_USER_AGENT'] || '-'
    session.member_email = email
    session
  end
end
