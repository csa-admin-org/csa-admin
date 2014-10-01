class Importer
  attr_reader :worksheet, :row_range

  def self.import(*args)
    new(*args).import
  end

  def initialize(filename, row_range)
    session = GoogleDrive.login(ENV['GD_EMAIL'], ENV['GD_PASS'])
    @worksheet = session.file_by_title(filename).worksheets.first
    @row_range = row_range
  end

  def import
    worksheet.rows[row_range].each { |row| create_member(row) }
  end

  private

  def create_member(row)
    Member.create(
      name: "#{row[8]} #{row[9]}",
      emails: row[10],
      phones: row[11],
      address: row[12],
      zip: zip(row[13]),
      city: city(row[13]),
      distribution_id: distribution_id(row)
    )
  end

  def zip(row)
    (loc = row.match(/(\d{4}) (.*)/)) ? loc[1] : nil
  end

  def city(row)
    (loc = row.match(/(\d{4}) (.*)/)) ? loc[2] : nil
  end

  def distribution_id(row)
    (1..5).find { |i| row[i] =~ /x/i }
  end
end
