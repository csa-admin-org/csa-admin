# frozen_string_literal: true

require "ostruct"
require "tempfile"
require "net/http"
require "uri"

module Billing
  class BAS
    LoginError = Class.new(StandardError)
    MaintenanceError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)

    GET_PAYMENTS_FROM = 1.month.ago
    BASE_URL = "https://wwwsec.abs.ch".freeze
    NO_DATA_INFO_MSG = "<INFO_MSG>Aucune donn\xE9e BVR n'a \xE9t\xE9 trouv\xE9e</INFO_MSG>".dup.force_encoding("ISO-8859-1")

    def initialize(credentials)
      @credentials = credentials.symbolize_keys
      @base_uri = URI(BASE_URL)
    end

    def payments_data
      body = get_camt54_body
      return [] unless body

      Tempfile.create { |f|
        f << body
        f.rewind
        Billing::CamtFile.new([ f ]).payments_data
      }
    rescue MaintenanceError
      []
    end

    def sepa_direct_debit_upload(*args)
      raise NotImplementedError, "Sepa direct debit upload with BAS is not supported"
    end

    def version
      @version ||= begin
        res = post("/authen/autologin.eval",
          FUNCTION: "GETVERSION",
          BANK: "ABS",
          LANGUAGE: "french")
        res.body[/<VERSION>(.*)<\/VERSION>/m, 1]
      end
    end

    def account_numbers
      post("/ebanking/extInterface.file",
        FUNCTION: "KTOUEBERSICHT",
        BANK: "ABS",
        LANGUAGE: "french")
    end

    private

    def post(path, params)
      req = Net::HTTP::Post.new(@base_uri + path)
      req.set_form_data(params)
      make_request(req)
    end

    def get(path)
      req = Net::HTTP::Get.new(@base_uri + path)
      make_request(req)
    end

    def make_request(req)
      init_session_and_login
      req["Cookie"] = @cookies.map { |k, v| "#{k}=#{v}" }.join("; ") # unless @cookies.empty?
      res = @http.request(req)
      update_cookies(res)
      res
    end

    def update_cookies(res)
      (res.get_fields("Set-Cookie") || []).each do |cookie|
        parts = cookie.split(";")
        name_value = parts.first.split("=", 2)
        @cookies[name_value[0]] = name_value[1] if name_value.size == 2
      end
    end

    def get_camt54_body
      res = post("/ebanking/extInterface.file",
        FUNCTION: "CAMT054DATA",
        BANK: "ABS",
        LANGUAGE: "french",
        VON_DAT: GET_PAYMENTS_FROM.strftime("%-e.%-m.%Y"),
        KONTO: @credentials.fetch(:account_number),
        WITH_OLD: 1)
      if res.body.include?("<FILE>")
        res.body[/<FILE>(.*)<\/FILE>/m, 1].force_encoding("UTF-8")
      elsif res.body.include?(NO_DATA_INFO_MSG)
        Rails.event.notify(:bas_no_data_available, status: res.code, body: res.body)
        nil
      else
        Error.notify("BAS CAMT054 GET issue", version: version, body: res.body)
        nil
      end
    end

    def init_session_and_login
      return if @http

      @http = Net::HTTP.new(@base_uri.host, @base_uri.port)
      @http.use_ssl = true
      @http.read_timeout = 20
      @http.open_timeout = 20
      @cookies = {}
      login
      self
    end

    def login
      res_one = autologin(:logon_stepone,
        VERTRAG: @credentials.fetch(:contract_number),
        PASSWORT: @credentials.fetch(:contract_password))
      res_two = autologin(:logon_steptwo, SECURID: signed_challenge(res_one))
      # Follow redirect to finish login
      get(res_two["location"])
    end

    def autologin(function, **args)
      res = post "/authen/autologin.eval", {
        FUNCTION: function.to_s.upcase,
        BANK: "ABS",
        LANGUAGE: "french"
      }.merge(args)
      if res.code.to_i == 302 && res.body.blank?
        Rails.event.notify(:bas_maintenance_error, status: res.code, body: res.body)
        raise MaintenanceError, "BAS probably in maintenance"
      end
      if !res.code.to_i.in?([ 200, 302 ]) || res.body[/<STATUS>(.*)<\/STATUS>/, 1] != "I0000"
        raise LoginError, "Login issue (#{res.code.to_i}):\n#{res.body}"
      end
      res
    end

    def signed_challenge(res)
      challenge = res.body[/<CHALLENGE>(.*)<\/CHALLENGE>/, 1]
      unless challenge
        raise LoginError, "Login Step Two issue, missing challenge (#{res.code}):\n#{res.body}"
      end
      pkey = OpenSSL::PKey::RSA.new(@credentials.fetch(:private_key))
      Base64.strict_encode64 pkey.sign("MD5", challenge)
    end
  end
end
