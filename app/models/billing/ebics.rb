module Billing
  class EBICS
    GET_PAYMENTS_FROM = 1.month.ago

    def initialize(credentials = {})
      @credentials = credentials
      @client = client
    end

    def payments_data
      files = get_camt54_files
      CamtFile.new(files).payments_data
    end

    private

    def get_camt54_files
      client.Z54(
        GET_PAYMENTS_FROM.to_date.to_s,
        Date.current.to_s)
    end

    def client
      Epics::Client.new(
        @credentials.fetch(:keys),
        @credentials.fetch(:secret),
        @credentials.fetch(:url),
        @credentials.fetch(:host_id),
        @credentials.fetch(:participant_id),
        @credentials.fetch(:client_id))
    end
  end
end

class Epics::Z54 < Epics::GenericRequest
  attr_accessor :from, :to

  def initialize(client, from, to)
    super(client)
    self.from = from
    self.to = to
  end

  def header
    Nokogiri::XML::Builder.new do |xml|
      xml.header(authenticate: true) {
        xml.static {
          xml.HostID host_id
          xml.Nonce nonce
          xml.Timestamp timestamp
          xml.PartnerID partner_id
          xml.UserID user_id
          xml.Product('EPICS - a ruby ebics kernel', 'Language' => 'fr')
          xml.OrderDetails {
            xml.OrderType 'Z54'
            xml.OrderAttribute 'DZHNN'
            xml.StandardOrderParams {
              xml.DateRange {
                xml.Start from
                xml.End to
              }
            }
          }
          xml.BankPubKeyDigests {
            xml.Authentication(client.bank_x.public_digest,
              Version: 'X002',
              Algorithm: 'http://www.w3.org/2001/04/xmlenc#sha256')
            xml.Encryption(client.bank_e.public_digest,
              Version: 'E002',
              Algorithm: 'http://www.w3.org/2001/04/xmlenc#sha256')
          }
          xml.SecurityMedium '0000'
        }
        xml.mutable {
          xml.TransactionPhase 'Initialisation'
        }
      }
    end.doc.root
  end
end

class Epics::Client
  def Z54(from, to)
    download_and_unzip(Epics::Z54, from, to)
  rescue Epics::Error::BusinessError => e
    if e.message.include?('EBICS_NO_DOWNLOAD_DATA_AVAILABLE')
      []
    else
      raise e
    end
  end
end
