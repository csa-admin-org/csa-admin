module InvoicesHelper
  def save_pdf_and_return_strings(invoice)
    invoice.send(:attach_pdf) unless invoice.pdf_file.attached?
    pdf = invoice.pdf_file.download
    # pdf_path = "tmp/invoice-#{Current.acp.name}-##{invoice.id}.pdf"
    # File.open(pdf_path, 'wb+') { |f| f.write(pdf) }
    PDF::Inspector::Text.analyze(pdf).strings
  end
end

RSpec.configure do |config|
  config.include(InvoicesHelper)
end
