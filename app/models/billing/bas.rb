module Billing
  class BAS
    LoginError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)
    URL = 'https://wwwsec.abs.ch'.freeze

    GET_PAYMENTS_FROM = 2.weeks.ago

    attr_reader :session

    def initialize(credentials)
      @credentials = credentials
      @session = init_session
      login
    end

    def payments_data
      get_isr_lines
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
      Date.new("20#{line[71..72]}".to_i, line[73..74].to_i, line[75..76].to_i)
    rescue ArgumentError
      nil
    end

    def isr_invoice_id(line)
      line[26..37].to_i
    end

    def isr_amount(line)
      line[40..48].to_i / BigDecimal(100)
    end

    def get_isr_lines
      res = @session.post('/ebanking/extInterface.file',
        FUNCTION: 'ESRGET',
        BANK: 'ABS',
        LANGUAGE: 'french',
        VON_DAT: GET_PAYMENTS_FROM.strftime('%e.%-m.%Y'),
        BIS_DAT: Time.current.strftime('%e.%-m.%Y'),
        WITH_OLD: 1)
      if res.body.include?('<FILE>')
        res.body[/<FILE>(.*)<\/FILE>/m, 1].delete(' ').split("\r\n")
      else
        []
      end
    end

    def init_session
      Faraday.new(URL) do |builder|
        builder.request :url_encoded
        builder.use :cookie_jar
        builder.adapter Faraday.default_adapter
      end
    end

    def login
      res_one = post_login(:logon_stepone,
        VERTRAG: @credentials.fetch(:contract_number),
        PASSWORT: @credentials.fetch(:contract_password))
      res_two = post_login(:logon_steptwo, SECURID: signed_challenge(res_one))
      # Follow redirect to finish login
      @session.get(res_two.headers['location'])
    end

    def signed_challenge(stepone_response)
      challenge = stepone_response.body[/<CHALLENGE>(.*)<\/CHALLENGE>/, 1]
      pkey = OpenSSL::PKey::RSA.new(@credentials.fetch(:private_key))
      Base64.strict_encode64 pkey.sign('MD5', challenge)
    end

    def post_login(function, **args)
      res = @session.post '/authen/autologin.eval', {
        FUNCTION: function.to_s.upcase,
        BANK: 'ABS',
        LANGUAGE: 'french',
      }.merge(args)
      if !res.status.in?([200, 302]) || res.body[/<STATUS>(.*)<\/STATUS>/, 1] != 'I0000'
        raise LoginError, "Login issue (#{res.status}):\n#{res.body}"
      end
      res
    end
  end
end
