class Gribouille < ActiveRecord::Base
  ATTACHMENTS_NUMBER = 3

  belongs_to :delivery

  has_many_attached :attachments

  ATTACHMENTS_NUMBER.times.each do |i|
    define_method "attachment_#{i}=" do |attachment|
      attachments.attach(attachment)
    end

    define_method "attachment_name_#{i}=" do |keep|
      unless keep.to_s == '1'
        attachments[i]&.purge_later
      end
    end

    define_method "attachment_name_#{i}" do
      attachments[i]&.filename&.to_s
    end
  end

  def deliverable?
    [header, basket_content].all?(&:present?) && !sent_at?
  end

  def display_name
    "Gribouille du #{delivery.date}"
  end
end
