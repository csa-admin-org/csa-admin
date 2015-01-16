class GribouilleEmailsController < ApplicationController
  before_action :verify_auth_token

  # GET /gribouille_emails.csv
  def index
    render text: Member.gribouille_emails.to_csv
  end

  private

  def verify_auth_token
    unless params[:auth_token] == ENV['GRIBOUILLE_AUTH_TOKEN']
      render text: 'unauthorized', status: :unauthorized
    end
  end
end
