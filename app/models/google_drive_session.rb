module GoogleDriveSession
  CONFIG_FILE_PATH = Rails.root.join('config/google_drive.json')

  def self.from_config_and_env
    config_file = open(CONFIG_FILE_PATH)
    config = JSON.parse(config_file.read)
    config['client_id'] = ENV['GOOGLE_DRIVE_CLIENT_ID']
    config['private_key_id'] = ENV['GOOGLE_DRIVE_PRIVATE_KEY_ID']
    config['private_key'] = ENV['GOOGLE_DRIVE_PRIVATE_KEY']
    GoogleDrive::Session.from_service_account_key(StringIO.new(JSON.dump(config)))
  end
end
