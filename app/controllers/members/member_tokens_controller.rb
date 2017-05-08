class Members::MemberTokensController < Members::ApplicationController
  skip_before_action :authenticate_member!

  # GET /token/recover
  def edit
  end

  # POST /token/recover
  def recover
    @member = Member.where('emails ILIKE ?', "%#{params[:email]}%").first
    MemberMailer.recover_token(params[:email], @member).deliver_later if @member
    redirect_to edit_members_member_token_path,
      notice: "Merci! Un email vient de vous être envoyé."
  end
end
