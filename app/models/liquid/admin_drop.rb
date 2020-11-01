class Liquid::AdminDrop < Liquid::Drop
  def initialize(admin)
    @admin = admin
  end

  def name
    @admin.name
  end

  def email
    @admin.email
  end
end
