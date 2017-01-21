class Inscription
  def self.import
    session = GoogleDriveSession.from_config_and_env
    worksheet = session.worksheet_by_url(ENV['INSCRIPTIONS_WORKSHEET_URL'])
    worksheet.rows[1..-1].each { |row| new(row).import }
  end

  def initialize(row)
    @row = row
  end

  def import
    return if old_entry? || already_imported?
    create_member!
  end

  def submitted_at
    Time.strptime(@row[0], '%m/%d/%Y %H:%M:%S')
  end

  def old_entry?
    submitted_at < 1.week.ago
  end

  def already_imported?
    Member
      .with_deleted
      .where(inscription_submitted_at: submitted_at)
      .exists?
  end

  def create_member!
    member = Member.create!(
      inscription_submitted_at: submitted_at,
      first_name: first_name,
      last_name: last_name,
      address: address,
      zip: zip,
      city: city,
      emails: @row[3],
      phones: @row[4],
      support_member: support?,
      waiting_basket_id: basket_id,
      waiting_distribution_id: distribution_id,
      billing_interval: billing_interval,
      food_note: @row[9],
      note: @row[11]
    )
    AdminMailer.new_inscription(member).deliver
  end

  def first_name
    @row[1].split(' ', 2).first
  end

  def last_name
    @row[1].split(' ', 2).last
  end

  def billing_interval
    @row[8] =~ /Trimestriel/ ? 'quarterly' : 'annual'
  end

  def support?
    !!(@row[5] =~ /soutien/)
  end

  def basket_id
    return if support?

    case @row[5]
    when /veil/ then Basket.find_by!(year: Time.zone.today.year, name: 'Eveil').id
    when /Abon/ then Basket.find_by!(year: Time.zone.today.year, name: 'Abondance').id
    end
  end

  def distribution_id
    return if support?

    case @row[12]
    when /Jardin/i then 1
    when /vélo/i then 2
    when /libre/i then 3
    when /Chaux-de-Fonds/i then 4
    when /marin/i then 5
    when /Chaux-du-Milieu/i then 6
    when /Colombier/i then 7
    end
  end

  def address
    a = @row[2].split(', ')
    a.size == 4 ? a[0..1].join(', ') : a.first
  end

  def zip
    @row[2].split(', ').last.scan(/\d{4}/).first.to_i
  end

  def city
    @row[2].split(', ')[-2]
  end
end
