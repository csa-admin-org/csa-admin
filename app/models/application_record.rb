class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def can_update?; true end
  def can_destroy?; true end

  def self.ransackable_attributes(auth_object = nil)
    authorizable_ransackable_attributes
  end

  def self.ransackable_associations(auth_object = nil)
    authorizable_ransackable_associations
  end
end
