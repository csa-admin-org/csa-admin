class Members::MemberTokensController < Members::ApplicationController
  skip_before_action :authenticate_member!

  # GET /token/recover
  def edit
  end

  # POST /token/recover
  def recover
  end
end
