# frozen_string_literal: true

require "test_helper"
require "nokogiri"

class Billing::SEPADirectDebitTest < ActiveSupport::TestCase
  test "returns owned pain.008.001.08 direct debit XML for invoices" do
    travel_to "2025-02-01"
    german_org(
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(
      language: "de",
      street: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    invoice1 = create_annual_fee_invoice(member: member)
    invoice2 = create_invoice(
      member: member,
      date: Date.yesterday,
      items_attributes: {
        "0" => { description: "A cool cheap thing", amount: 12.34 }
      })

    member.update!(billing_name: "Anna Changed")

    xml = Billing::SEPADirectDebit.new([ invoice1, invoice2 ]).xml
    assert_includes xml, "urn:iso:std:iso:20022:tech:xsd:pain.008.001.08"
    assert_includes xml, <<-XML
      <CreDtTm>2025-02-01T00:00:00+01:00</CreDtTm>
      <NbOfTxs>2</NbOfTxs>
      <CtrlSum>42.34</CtrlSum>
      <InitgPty>
        <Nm>Gläubiger GmbH</Nm>
        <Id>
          <OrgId>
            <Othr>
              <Id>DE98ZZZ09999999999</Id>
            </Othr>
          </OrgId>
        </Id>
      </InitgPty>
    XML
    assert_includes xml, <<-XML
      <PmtMtd>DD</PmtMtd>
      <BtchBookg>false</BtchBookg>
      <NbOfTxs>2</NbOfTxs>
      <CtrlSum>42.34</CtrlSum>
      <PmtTpInf>
        <SvcLvl>
          <Cd>SEPA</Cd>
        </SvcLvl>
        <LclInstrm>
          <Cd>CORE</Cd>
        </LclInstrm>
        <SeqTp>OOFF</SeqTp>
      </PmtTpInf>
      <ReqdColltnDt>1999-01-01</ReqdColltnDt>
      <Cdtr>
        <Nm>Gläubiger GmbH</Nm>
      </Cdtr>
      <CdtrAcct>
        <Id>
          <IBAN>DE87200500001234567890</IBAN>
        </Id>
      </CdtrAcct>
    XML
    assert_includes xml, <<-XML
      <DrctDbtTxInf>
        <PmtId>
          <InstrId>#{members(:anna).id}-#{invoice1.id}</InstrId>
          <EndToEndId>#{invoice1.reference}</EndToEndId>
        </PmtId>
        <InstdAmt Ccy="EUR">30.00</InstdAmt>
        <DrctDbtTx>
          <MndtRltdInf>
            <MndtId>123456</MndtId>
            <DtOfSgntr>2023-12-24</DtOfSgntr>
          </MndtRltdInf>
        </DrctDbtTx>
        <DbtrAgt>
          <FinInstnId>
            <Othr>
              <Id>NOTPROVIDED</Id>
            </Othr>
          </FinInstnId>
        </DbtrAgt>
        <Dbtr>
          <Nm>Anna Doe</Nm>
        </Dbtr>
        <DbtrAcct>
          <Id>
            <IBAN>DE21500500009876543210</IBAN>
          </Id>
        </DbtrAcct>
      </DrctDbtTxInf>
    XML
    assert_includes xml, <<-XML
      <DrctDbtTxInf>
        <PmtId>
          <InstrId>#{members(:anna).id}-#{invoice2.id}</InstrId>
          <EndToEndId>#{invoice2.reference}</EndToEndId>
        </PmtId>
        <InstdAmt Ccy="EUR">12.34</InstdAmt>
        <DrctDbtTx>
          <MndtRltdInf>
            <MndtId>123456</MndtId>
            <DtOfSgntr>2023-12-24</DtOfSgntr>
          </MndtRltdInf>
        </DrctDbtTx>
        <DbtrAgt>
          <FinInstnId>
            <Othr>
              <Id>NOTPROVIDED</Id>
            </Othr>
          </FinInstnId>
        </DbtrAgt>
        <Dbtr>
          <Nm>Anna Doe</Nm>
        </Dbtr>
        <DbtrAcct>
          <Id>
            <IBAN>DE21500500009876543210</IBAN>
          </Id>
        </DbtrAcct>
      </DrctDbtTxInf>
    XML
  end

  test "returns structurally valid pain.008.001.08 direct debit XML" do
    travel_to "2025-02-01"
    german_org(
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)
    xml = Billing::SEPADirectDebit.new(
      invoice,
      schema: Billing::SEPADirectDebit::PAIN_008_001_08).xml

    document = Nokogiri::XML(xml)
    namespace = "urn:iso:std:iso:20022:tech:xsd:pain.008.001.08"
    ns = { pain: namespace }

    assert_equal namespace, document.root.namespace.href
    assert_equal "#{namespace} pain.008.001.08.xsd", document.root["xsi:schemaLocation"]
    assert_equal "CSAADMIN/", text(document, "//pain:GrpHdr/pain:MsgId", ns).first(9)
    assert_equal "2025-02-01T00:00:00+01:00", text(document, "//pain:GrpHdr/pain:CreDtTm", ns)
    assert_equal "1", text(document, "//pain:GrpHdr/pain:NbOfTxs", ns)
    assert_equal "30.00", text(document, "//pain:GrpHdr/pain:CtrlSum", ns)
    assert_equal "DD", text(document, "//pain:PmtInf/pain:PmtMtd", ns)
    assert_equal "false", text(document, "//pain:PmtInf/pain:BtchBookg", ns)
    assert_equal "SEPA", text(document, "//pain:PmtTpInf/pain:SvcLvl/pain:Cd", ns)
    assert_equal "CORE", text(document, "//pain:PmtTpInf/pain:LclInstrm/pain:Cd", ns)
    assert_equal "OOFF", text(document, "//pain:PmtTpInf/pain:SeqTp", ns)
    assert_equal "1999-01-01", text(document, "//pain:PmtInf/pain:ReqdColltnDt", ns)
    assert_equal "NOTPROVIDED", text(document, "//pain:DbtrAgt/pain:FinInstnId/pain:Othr/pain:Id", ns)
    assert_equal "30.00", text(document, "//pain:DrctDbtTxInf/pain:InstdAmt", ns)
    assert_equal "EUR", document.at_xpath("//pain:DrctDbtTxInf/pain:InstdAmt", ns)["Ccy"]
    assert_equal "123456", text(document, "//pain:MndtId", ns)
    assert_equal "2023-12-24", text(document, "//pain:DtOfSgntr", ns)
  end

  test "raises for unsupported direct debit XML schemas" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)

    error = assert_raises(ArgumentError) do
      Billing::SEPADirectDebit.new(invoice, schema: "pain.008.001.99").xml
    end
    assert_equal "Unsupported SEPA direct debit schema: \"pain.008.001.99\"", error.message
  end

  test "return nil when no invoices" do
    assert_nil Billing::SEPADirectDebit.new([]).xml
  end

  test "return nil with no sepa invoice" do
    invoice = create_annual_fee_invoice(member: members(:anna))
    assert_not invoice.sepa?
    assert invoice.open?
    assert_nil Billing::SEPADirectDebit.new(invoice).xml
  end

  test "return nil with closed sepa invoice" do
    german_org(
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(
      language: "de",
      street: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload

    invoice = create_annual_fee_invoice(member: member)
    create_payment(invoice: invoice, amount: 30)
    invoice.reload

    assert invoice.sepa?
    assert invoice.closed?
    assert_nil Billing::SEPADirectDebit.new(invoice).xml
  end

  private

  def text(document, xpath, namespaces)
    document.at_xpath(xpath, namespaces).text
  end
end
