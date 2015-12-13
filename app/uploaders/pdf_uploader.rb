class PdfUploader < CarrierWave::Uploader::Base
  storage :postgresql_lo
end
