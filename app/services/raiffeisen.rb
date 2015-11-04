class Raiffeisen
  URL = 'https://ebanking.raiffeisen.ch'
  P12 = Rails.root.join('config', 'raiffeisen.p12').to_s

  attr_reader :client

  def initialize
    @client = Faraday.new(URL, ssl: ssl_options) do |builder|
      builder.request :url_encoded
      builder.use :cookie_jar
      builder.adapter Faraday.default_adapter
    end
    login
  end

  def get_esr_data
    client.get '/root/datatransfer/esrdownload',
      ESRAccountNumber: 'all',
      ESRDataType: 'allESR',
      Download: 'Abholen',
      output: 'xml'
  end

  private

  def login
    client.post '/softCertLogin/offlinetool',
      password: ENV['RAIFFEISEN_PASSWORD']
  end

  def ssl_options
    p12 = OpenSSL::PKCS12.new File.read(P12)
    { client_cert: p12.certificate, client_key: p12.key }
  end
end
