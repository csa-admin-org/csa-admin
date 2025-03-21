# frozen_string_literal: true

require "test_helper"

class Billing::SEPADirectDebitTest < ActiveSupport::TestCase
  test "returns direct debit XML pain file for invoices" do
    travel_to "2025-02-01"
    german_org(
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24",
      address: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")

    invoice1 = create_annual_fee_invoice(member: member)
    invoice2 = create_invoice(
      member: member,
      date: Date.yesterday,
      items_attributes: {
        "0" => { description: "A cool cheap thing", amount: 12.34 }
      })

    xml = Billing::SEPADirectDebit.xml([ invoice1, invoice2 ])
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
      <BtchBookg>true</BtchBookg>
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

  test "return nil when no invoices" do
    assert_nil Billing::SEPADirectDebit.xml([])
  end

  test "return nil with no sepa invoice" do
    invoice = create_annual_fee_invoice(member: members(:anna))
    assert_not invoice.sepa?
    assert invoice.open?
    assert_nil Billing::SEPADirectDebit.xml(invoice)
  end

  test "return nil with closed sepa invoice" do
    german_org(
      iban: "DE87200500001234567890",
      sepa_creditor_identifier: "DE98ZZZ09999999999")
    member = members(:anna)
    member.update!(
      language: "de",
      iban: "DE21500500009876543210",
      sepa_mandate_id: "123456",
      sepa_mandate_signed_on: "2023-12-24",
      address: "Grosse Marktgasse 28",
      zip: "30952",
      city: "Ronnenberg",
      country_code: "DE")

    invoice = create_annual_fee_invoice(member: member)
    create_payment(invoice: invoice, amount: 30)
    invoice.reload

    assert invoice.sepa?
    assert invoice.closed?
    assert_nil Billing::SEPADirectDebit.xml(invoice)
  end
end
