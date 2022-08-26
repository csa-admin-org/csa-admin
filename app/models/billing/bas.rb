require 'tempfile'

module Billing
  class BAS
    LoginError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)
    URL = 'https://wwwsec.abs.ch'.freeze

    GET_PAYMENTS_FROM = 1.month.ago
    NO_DATA_INFO_MSG = "<INFO_MSG>Aucune donn\xE9e BVR n'a \xE9t\xE9 trouv\xE9e</INFO_MSG>".force_encoding('ISO-8859-1')

    attr_reader :session

    def initialize(credentials)
      @credentials = credentials
      @session = init_session
      login
    end

    def payments_data
      body = get_camt54_body
      return unless body

      Tempfile.create { |f|
        f << body
        f.rewind
        Billing::CamtFile.new([f]).payments_data
      }
    end

    def version
      @version ||= begin
        res = @session.post('/authen/autologin.eval',
          FUNCTION: 'GETVERSION',
          BANK: 'ABS',
          LANGUAGE: 'french')
        res.body[/<VERSION>(.*)<\/VERSION>/m, 1]
      end
    end

    private

    def get_camt54_body
      res = @session.post('/ebanking/extInterface.file',
        FUNCTION: 'CAMT054DATA',
        BANK: 'ABS',
        LANGUAGE: 'french',
        VON_DAT: GET_PAYMENTS_FROM.strftime('%-e.%-m.%Y'),
        KONTO: @credentials.fetch(:account_number),
        WITH_OLD: 1)
      if res.body.include?('<FILE>')
        res.body[/<FILE>(.*)<\/FILE>/m, 1].force_encoding('UTF-8')
      elsif res.body.include?(NO_DATA_INFO_MSG)
        nil
      else
        Sentry.capture_message('BAS CAMT054 GET issue', extra: {
          version: version,
          body: res.body
        })
        nil
      end
    end

    def get_account_numbers
      res = @session.post('/ebanking/extInterface.file',
        FUNCTION: 'KTOUEBERSICHT',
        BANK: 'ABS',
        LANGUAGE: 'french')
    end

    def init_session
      Faraday.new(URL) do |builder|
        builder.request :url_encoded
        builder.use :cookie_jar
        builder.adapter Faraday.default_adapter
        builder.options[:timeout] = 20
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
      unless challenge
        raise LoginError, "Login Step Two issue, missing challenge (#{stepone_response.status}):\n#{stepone_response.body}"
      end
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
