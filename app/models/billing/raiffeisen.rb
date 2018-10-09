module Billing
  class Raiffeisen
    PaymentData = Class.new(OpenStruct)
    URL = 'https://ebanking.raiffeisen.ch'.freeze

    def initialize(credentials)
      @credentials = credentials
      @session = session
    end

    def payments_data
      get_isr_lines(:all)
        .group_by(&:itself)
        .flat_map { |_line, lines|
          lines.map.with_index { |line, i|
            PaymentData.new(
              invoice_id: isr_invoice_id(line),
              amount: isr_amount(line),
              date: isr_date(line),
              isr_data: "#{i}-#{line}")
          }
        }
        .reject { |pd| pd.invoice_id > 9999999 || !pd.date }
    end

    private

    def isr_date(line)
      Date.new("20#{line[69..70]}".to_i, line[71..72].to_i, line[73..74].to_i)
    rescue ArgumentError
      nil
    end

    def isr_invoice_id(line)
      line[26..37].to_i
    end

    def isr_amount(line)
      line[40..48].to_i / BigDecimal(100)
    end

    def get_isr_lines(type)
      response = @session.get '/root/datatransfer/esrdownload',
        ESRAccountNumber: 'all',
        ESRDataType: "#{type}ESR", # all, new or old
        Download: 'Abholen'
      if response.body.start_with?('<html>')
        []
      else
        response.body.delete(' ').split("\r\n")
      end
    end

    def session
      sess = Faraday.new(URL, ssl: ssl_options) do |builder|
        builder.request :url_encoded
        builder.use :cookie_jar
        builder.adapter Faraday.default_adapter
      end
      sess.post '/softCertLogin/offlinetool', password: @credentials.fetch(:password)
      sess
    end

    def ssl_options
      {
        client_key: OpenSSL::PKey.read(@credentials.fetch(:private_key)),
        client_cert: OpenSSL::X509::Certificate.new(@credentials.fetch(:certificate))
      }
    end
  end
end
