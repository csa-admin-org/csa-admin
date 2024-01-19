class InvoicesPDFZipper
  def self.zip(invoices)
    new(invoices).zip
  end

  def initialize(invoices)
    @invoices = invoices.preload(pdf_file_attachment: :blob)
  end

  def zip
    zip = Tempfile.new
    download_and_zip_pdfs(zip)
    zip
  ensure
    zip.close
  end

  private

  def download_and_zip_pdfs(file)
    Dir.mktmpdir do |dir|
      Parallel.map(@invoices.map(&:pdf_file)) do |pdf|
        download(dir, pdf)
      end
      zip_pdfs(dir, file)
    end
  end

  def download(dir, pdf)
    File.open(File.join(dir, pdf.filename.to_s), "wb") do |file|
      pdf.download { |chunk| file.write(chunk) }
    end
  end

  def zip_pdfs(dir, file)
    Zip::File.open(file, create: true) do |zip|
      Dir.glob("#{dir}/*.pdf").each do |pdf_path|
        pdf_filename = pdf_path.split("/").last
        zip.add(pdf_filename, pdf_path)
      end
    end
  end
end
