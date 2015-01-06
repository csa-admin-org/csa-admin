class GoogleAccessTokenFetcher
  attr_reader :key, :client

  def self.access_token
    new.access_token
  end

  def initialize
    @key = Google::APIClient::KeyUtils.load_from_pkcs12(
      Rails.root.join('config/google_pkcs12.p12').to_s,
      'notasecret'
    )
    @client = Google::APIClient.new(
      application_name: 'Admin RageDeVert',
      application_version: '1.0.0'
    )
    client.authorization = Signet::OAuth2::Client.new(
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      audience: 'https://accounts.google.com/o/oauth2/token',
      scope: [
        'https://www.googleapis.com/auth/drive',
        'https://spreadsheets.google.com/feeds'
      ],
      issuer: '705404364929-b48vdqp15lhqjq4ksu18ttt7hah3s885@developer.gserviceaccount.com',
      signing_key: key
    )
  end

  def access_token
    client.authorization.fetch_access_token!
    client.authorization.access_token
  end
end
