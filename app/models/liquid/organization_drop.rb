# frozen_string_literal: true

class Liquid::OrganizationDrop < Liquid::Drop
  def initialize(org)
    @org = org
  end

  def name
    @org.name
  end

  def url
    @org.url
  end

  def email
    @org.email
  end

  def phone
    @org.phone
  end

  def activity_phone
    @org.activity_phone
  end
end
