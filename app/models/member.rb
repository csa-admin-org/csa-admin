class Member < ActiveRecord::Base
  has_many :halfday_works
  belongs_to :distribution

  def emails
    read_attribute(:emails).try(:join, ', ')
  end

  def emails=(string)
    write_attribute :emails, string.split(',').each(&:strip!)
  end

  def phones
    read_attribute(:phones).try(:join, ', ')
  end

  def phones=(string)
    write_attribute :phones, string.split(',').each(&:strip!)
  end
end
