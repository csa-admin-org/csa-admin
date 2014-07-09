class Member < ActiveRecord::Base
  def emails=(string)
    write_attribute :emails, string.split(',').each(&:strip!)
  end

  def phones=(string)
    write_attribute :phones, string.split(',').each(&:strip!)
  end
end
