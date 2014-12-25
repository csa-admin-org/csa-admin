class Members::MemberTokensController < Members::ApplicationController
  skip_before_action :authenticate_member!

  # GET /token/recover
  def edit
  end

  # POST /token/recover
  def recover
    @member = Member.where('emails LIKE ?', "%#{params[:email]}%").first
    MemberMailer.recover_token_email(params[:email], @member).deliver if @member
    redirect_to edit_members_member_token_path,
      notice: "Merci, si l'email correspond à un membre, un email vient de vous être envoyé."
  end
end
