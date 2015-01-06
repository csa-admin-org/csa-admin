require 'google_access_token_fetcher'

class SupportImporter
  attr_reader :worksheet, :row_range

  def self.import(*args)
    new(*args).import
  end

  def initialize(filename, row_range)
    access_token = GoogleAccessTokenFetcher.access_token
    session = GoogleDrive.login_with_oauth(access_token)
    @worksheet = session.file_by_title(filename).worksheets.first
    @row_range = row_range
  end

  def import
    worksheet.rows[row_range].each_with_index { |row, i| create_member(row, i) }
  end

  private

  def create_member(row, index)
    p "---------------"
    p row.inspect
    member =
      Member.inactive.find_by(first_name: row[0], last_name: row[1]) ||
      Member.new(
        first_name: row[0],
        last_name: row[1],
        address: row[2],
        zip: row[3].to_i,
        city: row[4],
        phones: row[5],
        emails: row[6],
        validated_at: Time.now.utc,
        validator: Admin.first,
        note: row[10]
      )
    member.support_member = true
    member.billing_interval = 'annual'
    member.save!
    p member.inspect
  end
end
