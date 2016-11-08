class AttachmentUploader < CarrierWave::Uploader::Base
  storage :postgresql_lo
end
