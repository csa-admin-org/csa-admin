require 'google_access_token_fetcher'

class InscriptionsImporter
  attr_reader :worksheet

  def self.import
    new.import
  end

  def initialize
    access_token = GoogleAccessTokenFetcher.access_token
    session = GoogleDrive.login_with_oauth(access_token)
    @worksheet = session.file_by_title('Inscriptions').worksheets.first
  end

  def import
    worksheet.rows[1..-1].each do |row|
      next if old_entry?(row)
      next if already_imported?(row)
      create_member(row)
    end
  end

  private

  def create_member(row)
    member = Member.create!(
      inscription_submitted_at: inscription_submitted_at(row),
      first_name: row[1].split(' ', 2).first,
      last_name: row[1].split(' ', 2).last,
      address: address(row[2]),
      zip: zip(row[2]),
      city: city(row[2]),
      emails: row[3],
      phones: row[4],
      support_member: support?(row[5]),
      waiting_basket_id: support?(row[5]) ? nil : basket_id(row[5]),
      waiting_distribution_id: support?(row[5]) ? nil : distribution_id(row[12]),
      billing_interval:  row[8] =~ /Trimestriel/ ? 'quarterly' : 'annual',
      food_note: row[9],
      note: row[11]
    )
    AdminMailer.new_inscription(member).deliver
  end

  def old_entry?(row)
    inscription_submitted_at(row) < 1.week.ago
  end

  def already_imported?(row)
    Member
      .with_deleted
      .where(inscription_submitted_at: inscription_submitted_at(row))
      .exists?
  end

  def inscription_submitted_at(row)
    Time.strptime(row[0], '%m/%d/%Y %H:%M:%S')
  end

  def support?(str)
    !!(str =~ /soutien/)
  end

  def basket_id(str)
    case str
    when /veil/ then Basket.find_by(year: Time.zone.today.year, name: 'Eveil').id
    when /Abon/ then Basket.find_by(year: Time.zone.today.year, name: 'Abondance').id
    else nil
    end
  end

  def distribution_id(str)
    case str
    when /Jardin/i then 1
    when /vélo/i then 2
    when /libre/i then 3
    when /Chaux-de-Fonds/i then 4
    when /marin/i then 5
    when /Chaux-du-Milieu/i then 6
    when /Colombier/i then 7
    else nil
    end
  end

  def address(str)
    a = str.split(', ')
    a.size == 4 ? a[0..1].join(', ') : a.first
  end

  def zip(str)
    str.split(', ').last.scan(/\d{4}/).first.to_i
  end

  def city(str)
    str.split(', ')[-2]
  end
end
