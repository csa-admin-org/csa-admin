# To be included inside the controller block
module TranslatedCSVFilename
  extend ActiveSupport::Concern

  def csv_filename
    "#{resource_class.model_name.human(count: 2).downcase.dasherize.delete(' ')}-#{Time.zone.now.to_date.to_s(:default)}.csv"
  end
end
