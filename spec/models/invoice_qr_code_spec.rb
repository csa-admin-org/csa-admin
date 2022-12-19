require 'rails_helper'

describe InvoiceQRCode do
  before {
    Current.acp.update!(
      country_code: 'CH',
      qr_iban: 'CH4431999123000889012',
      qr_creditor_name: 'Robert Schneider AG',
      qr_creditor_address: 'Rue du Lac 1268',
      qr_creditor_city: 'Biel',
      qr_creditor_zip: '2501',
      invoice_info: 'Payable dans les 30 jours, avec nos remerciements.',
      invoice_footer: '<b>Association Rage de Vert</b>, Closel-Bourbon 3, 2075 Thielle /// info@ragedevert.ch, 076 481 13 84')
  }
  let(:member) {
    create(:member,
      id: 1234,
      name: 'Pia-Maria Rutschmann-Schnyder',
      address: 'Grosse Marktgasse 28',
      zip: '9400',
      city: 'Rorschach',
      country_code: 'CH')
  }

  specify '#payload' do
    invoice = create(:invoice, :annual_fee, id: 706, member: member)
    invoice.payments.create!(amount: 10, date: Date.today)
    payload = InvoiceQRCode.new(invoice.reload).payload
    expect(payload).to eq(
      "SPC\r\n" +
      "0200\r\n" +
      "1\r\n" +
      "CH4431999123000889012\r\n" +
      "S\r\n" +
      "Robert Schneider AG\r\n" +
      "Rue du Lac 1268\r\n" +
      "\r\n" +
      "2501\r\n" +
      "Biel\r\n" +
      "CH\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "20.00\r\n" +
      "CHF\r\n" +
      "S\r\n" +
      "Pia-Maria Rutschmann-Schnyder\r\n" +
      "Grosse Marktgasse 28\r\n" +
      "\r\n" +
      "9400\r\n" +
      "Rorschach\r\n" +
      "CH\r\n" +
      "QRR\r\n" +
      "000000000000012340000007067\r\n" +
      "Facture 706\r\n" +
      "EPD\r\n" +
      "\r\n")
  end

  specify '#generate_qr_image' do
    expected = MiniMagick::Image.open file_fixture('qrcode-706.png')
    invoice = create(:invoice, :annual_fee, id: 706, member: member)
    result = InvoiceQRCode.new(invoice).generate_qr_image(rails_env: 'not_test')
    # result.write("#{Rails.root}/tmp/qrcode-#{invoice.id}.png")
    expect(result).to eq expected
  end
end
