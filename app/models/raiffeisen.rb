class Raiffeisen
  URL = 'https://ebanking.raiffeisen.ch'.freeze

  attr_reader :client

  def initialize
    @client = Faraday.new(URL, ssl: ssl_options) do |builder|
      builder.request :url_encoded
      builder.use :cookie_jar
      builder.adapter Faraday.default_adapter
    end
    login
  end

  def get_isr_data(type = :all)
    raw_data = new_isr_download(type)
    lines = raw_data.delete(' ').split("\r\n")
    lines.map { |line|
      {
        invoice_id: line[26..37].to_i,
        amount: line[40..48].to_i / 100.0,
        data: line
      }
    }.reject { |h| h[:invoice_id] > 9999999 || h[:data].in?(ignored_isr_datas) }
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
    {
      client_key: OpenSSL::PKey.read(ENV['RAIFFEISEN_KEY']),
      client_cert: OpenSSL::X509::Certificate.new(ENV['RAIFFEISEN_CERT'])
    }
  end

  def ignored_isr_datas
    path = Rails.root.join('config/ignored_isr.yml')
    file = File.read(path)
    YAML.load(file)
  end
end
