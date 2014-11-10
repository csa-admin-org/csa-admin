class Member < ActiveRecord::Base
  has_many :halfday_works
  belongs_to :distribution

  uniquify :token, length: 10

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

  def remaining_halfday_works_count
    4 - halfday_works.past.validated.to_a.sum(&:value)
  end

  def to_param
    token
  end
end
