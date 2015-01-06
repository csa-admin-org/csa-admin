require 'google_access_token_fetcher'

class Importer
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
    member = Member.new(
      first_name: row[5].presence || row[4],
      last_name: row[6],
      emails: row[7],
      phones: row[8],
      address: row[9],
      zip: row[10].to_i,
      city: row[11],
      validated_at: Time.now.utc,
      validator: Admin.first,
      support_member: false,
      billing_interval: row[19] == 'annuel' ? 'annual' : 'quarterly',
      food_note: row[28],
      note: (row[32] + "\n\n" + row[34]).chop.chop,
    )
    if ['OK 2015', 'Invités', 'Liste attente', 'Panier salaire'].include?(row[1]) && basket(row[12])
      member.memberships.build(
        member: member,
        basket: basket(row[12]),
        distribution: distribution(row[2]),
        started_on: Date.new(2015).beginning_of_year,
        ended_on: Date.new(2015).end_of_year
      )
    end
    if ['Liste attente', 'Invités'].include?(row[1])
      member.waiting_started_at = Time.now - (200 - index).minutes
    end
    if row[1] == 'Panier salaire'
      member.memberships.first.annual_price = 0
      member.memberships.first.annual_halfday_works = 0
    end
    member.save!
    p member.inspect
  end

  private

  def distribution(name)
    case name
    when 'Jardin', '' then Distribution.find_by(name: 'Jardin de la main')
    when 'CDF' then Distribution.find_by(name: "L'Entre-deux")
    when 'Marin' then Distribution.find_by(name: 'Particulier')
    when 'Vélo' then Distribution.find_by(name: 'Vélo')
    when 'Vin Libre' then Distribution.find_by(name: 'Vin libre')
    else raise 'unknown distribution name'
    end
  end

  def basket(name)
    case name
    when /eveil/i then Basket.find_by(name: 'Eveil')
    when /abondance/i then Basket.find_by(name: 'Abondance')
    else nil
    end
  end
end
