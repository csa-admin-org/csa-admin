# frozen_string_literal: true

# Reduced organization drop for public newsletter projections.
# Intentionally omits dynamic/member-adjacent data such as next_delivery.
class Liquid::PublicOrganizationDrop < Liquid::Drop
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
end
