# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class SEPADirectDebit
    class Pain008
      SCHEMA = SEPADirectDebit::PAIN_008_001_08

      def initialize(invoices)
        @invoices = invoices
      end

      def xml
        Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.Document(xml_schema) {
            xml.CstmrDrctDbtInitn {
              group_header(xml)
              payment_information(xml)
            }
          }
        end.to_xml
      end

      private
        attr_reader :invoices

        def xml_schema
          namespace = "urn:iso:std:iso:20022:tech:xsd:#{SCHEMA}"
          {
            xmlns: namespace,
            "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
            "xsi:schemaLocation": "#{namespace} #{SCHEMA}.xsd"
          }
        end

        def group_header(xml)
          xml.GrpHdr {
            xml.MsgId message_identification
            xml.CreDtTm Time.current.iso8601
            xml.NbOfTxs invoices.size
            xml.CtrlSum amount_total
            xml.InitgPty {
              xml.Nm Current.org.creditor_name
              xml.Id {
                xml.OrgId {
                  xml.Othr {
                    xml.Id Current.org.sepa_creditor_identifier
                  }
                }
              }
            }
          }
        end

        def payment_information(xml)
          xml.PmtInf {
            xml.PmtInfId "#{message_identification}/1"
            xml.PmtMtd "DD"
            xml.BtchBookg false
            xml.NbOfTxs invoices.size
            xml.CtrlSum amount_total
            payment_type_information(xml)
            xml.ReqdColltnDt SEPA::Transaction::DEFAULT_REQUESTED_DATE.iso8601
            creditor(xml)
            invoices.each { |invoice| direct_debit_transaction(xml, invoice) }
          }
        end

        def payment_type_information(xml)
          xml.PmtTpInf {
            xml.SvcLvl {
              xml.Cd "SEPA"
            }
            xml.LclInstrm {
              xml.Cd "CORE"
            }
            xml.SeqTp "OOFF"
          }
        end

        def creditor(xml)
          xml.Cdtr {
            xml.Nm Current.org.creditor_name
          }
          xml.CdtrAcct {
            xml.Id {
              xml.IBAN Current.org.iban
            }
          }
          xml.CdtrAgt {
            financial_institution(xml)
          }
          xml.ChrgBr "SLEV"
          xml.CdtrSchmeId {
            xml.Id {
              xml.PrvtId {
                xml.Othr {
                  xml.Id Current.org.sepa_creditor_identifier
                  xml.SchmeNm {
                    xml.Prtry "SEPA"
                  }
                }
              }
            }
          }
        end

        def direct_debit_transaction(xml, invoice)
          xml.DrctDbtTxInf {
            xml.PmtId {
              xml.InstrId [ invoice.member_id, invoice.id ].join("-")
              xml.EndToEndId invoice.reference
            }
            xml.InstdAmt amount(invoice.amount), Ccy: Current.org.currency_code
            xml.DrctDbtTx {
              xml.MndtRltdInf {
                xml.MndtId invoice.sepa_mandate.umr
                xml.DtOfSgntr invoice.sepa_mandate.signed_on.iso8601
              }
            }
            xml.DbtrAgt {
              financial_institution(xml)
            }
            xml.Dbtr {
              xml.Nm invoice.sepa_debtor_name
            }
            xml.DbtrAcct {
              xml.Id {
                xml.IBAN invoice.sepa_mandate.iban
              }
            }
          }
        end

        def financial_institution(xml)
          xml.FinInstnId {
            xml.Othr {
              xml.Id "NOTPROVIDED"
            }
          }
        end

        def amount_total
          amount(invoices.sum(&:amount))
        end

        def amount(value)
          format("%.2f", value)
        end

        def message_identification
          @message_identification ||= "CSAADMIN/#{SecureRandom.hex(11)}"
        end
    end
  end
end
