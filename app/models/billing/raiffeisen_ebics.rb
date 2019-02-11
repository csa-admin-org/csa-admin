module Billing
  class RaiffeisenEbics
    PaymentData = Class.new(OpenStruct)
    URL = 'https://econnect.raiffeisen.ch/ebicsweb/ebicsweb'.freeze
    GET_PAYMENTS_FROM = 1.month.ago

    def initialize(**credentials)
      @credentials = credentials
      @client = client
    end

    def payments_data
      camt54 = get_camt54
      camt54.notifications.flat_map do |notification|
        notification.entries.flat_map do |entry|
          date = entry.value_date
          entry.transactions.each_with_index.map do |transaction, i|
            ref = transaction.creditor_reference
            if transaction.credit? && ref.present?
              bank_ref = transaction.bank_reference
              PaymentData.new(
                invoice_id: ref.last(10).first(9).to_i,
                amount: transaction.amount,
                date: date,
                isr_data: "#{date}-#{bank_ref}-#{ref}-#{i}")
            end
          end.compact
        end
      end
    end

    private

    def get_camt54
      res = client.Z54(
        GET_PAYMENTS_FROM.to_date.to_s,
        Date.current.to_s
      ).first
      CamtParser::String.parse(res)
    end

    def client
      Epics::Client.new(
        @credentials.fetch(:keys),
        @credentials.fetch(:secret),
        URL,
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
  end
end
