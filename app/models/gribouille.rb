class Gribouille < ActiveRecord::Base
  belongs_to :delivery

  3.times.each do |i|
    mount_uploader "attachment_#{i}".to_sym, AttachmentUploader

    define_method "attachment_#{i}=" do |file|
      super(file)
      self["attachment_name_#{i}"] = file&.original_filename
      self["attachment_mime_type_#{i}"] = file&.content_type
    end

    define_method "attachment_name_#{i}=" do |keep|
      unless keep.to_s == '1'
        self.send("attachment_#{i}=", nil)
      end
    end
  end

  def deliverable?
    [header, basket_content].all?(&:present?) && !sent_at?
  end

  def display_name
    "Gribouille du #{delivery.date}"
  end
end
