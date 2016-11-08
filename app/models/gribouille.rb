class Gribouille < ActiveRecord::Base
  belongs_to :delivery

  mount_uploader :attachment, AttachmentUploader

  def attachment=(file)
    super
    self[:attachment_name] = file&.original_filename
    self[:attachment_mime_type] = file&.content_type
  end

  # If attachment_name checkbox is false, then delete attachment
  def attachment_name=(keep)
    unless keep.to_s == '1'
      self.attachment = nil
    end
  end

  def deliverable?
    [header, basket_content].all?(&:present?) && !sent_at?
  end
end
