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

  def get_isr_data(type = :new)
    raw_data = new_isr_download(type)
    lines = raw_data.split("\r\n").select { |l| l.start_with?('002010137346') }
    lines.map do |line|
      line = line.delete(' ').gsub(/^002010137346/, '')
      {
        invoice_id: line[14..25].to_i,
        amount: line[27..36].to_i / 100.0,
        data: line,
      }
    end
  end

  private

  def new_isr_download(type)
    response = client.get '/root/datatransfer/esrdownload',
      ESRAccountNumber: 'all',
      ESRDataType: "#{type}ESR", # all, new or old
      Download: 'Abholen'
    response.body.start_with?('<html>') ? '' : response.body
  end

  def login
    client.post '/softCertLogin/offlinetool',
      password: ENV['RAIFFEISEN_PASSWORD']
  end

  def ssl_options
    p12 = OpenSSL::PKCS12.new File.read(P12)
    { client_cert: p12.certificate, client_key: p12.key }
  end
end
