class Liquid::EmailSuppressionDrop < Liquid::Drop
  def initialize(email_suppression)
    @email_suppression = email_suppression
  end

  def email
    @email_suppression.email
  end

  def reason
    @email_suppression.reason
  end

  def owners
    @email_suppression.owners.map do |owner|
      case owner
      when Member; Liquid::AdminMemberDrop.new(owner)
      when Depot; Liquid::AdminDepotDrop.new(owner)
      when Admin; Liquid::AdminDrop.new(owner)
      end
    end
  end
end
