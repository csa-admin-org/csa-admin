class GribouilleEmailsController < ApplicationController
  include HasAuthToken

  before_action { verify_auth_token(:gribouille) }

  # GET /gribouille_emails.csv
  def index
    render plain: Member.gribouille_emails.to_csv
  end
end
