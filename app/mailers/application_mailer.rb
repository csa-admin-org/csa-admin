class ApplicationMailer < ActionMailer::Base
  default from: 'Rage de Vert <info@ragedevert.ch>'
  layout 'mailer'

  def default_url_options
    { host: 'membres.ragedevert.ch' }
  end
end
