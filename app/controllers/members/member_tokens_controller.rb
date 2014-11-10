class Members::MemberTokensController < Members::ApplicationController
  skip_before_action :authenticate_member!

  # GET /token/recover
  def edit
  end

  # POST /token/recover
  def recover
    @member = Member.find_by('? = ANY(emails)', params[:email])
    MemberMailer.recover_token_email(params[:email], @member).deliver if @member
    redirect_to edit_member_token_path,
      notice: "Merci, si l'email correspond à un membre, un email vient de vous être envoyé."
  end
end
