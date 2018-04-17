class Inscription
  def self.import_from_google_sheet(worksheet_url)
    session = GoogleDrive::Session.from_service_account_key(
      StringIO.new(Current.acp.credentials(:google_service_account)))
    worksheet = session.worksheet_by_url(worksheet_url)
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
      name: [last_name, first_name].join(' '),
      address: address,
      zip: zip,
      city: city,
      emails: @row[3],
      phones: @row[4],
      support_member: support?,
      waiting_basket_size_id: basket_size_id,
      waiting_distribution_id: distribution_id,
      billing_year_division: billing_year_division,
      food_note: @row[9],
      note: @row[11]
    )
    notify_admins(member)
  end

  def first_name
    @row[1].split(' ', 2).first
  end

  def last_name
    @row[1].split(' ', 2).last
  end

  def billing_year_division
    @row[8] =~ /Trimestriel/ ? 4 : 1
  end

  def support?
    !!(@row[5] =~ /soutien/)
  end

  def basket_size_id
    return if support?

    case @row[5]
    when /veil/ then BasketSize.first.id
    when /Abon/ then BasketSize.last.id
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

  def notify_admins(member)
    Admin.notification('new_inscription').find_each do |admin|
      Email.deliver_now(:member_new, admin, member)
    end
  end
end
