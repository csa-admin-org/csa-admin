class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def can_update?; true end
  def can_destroy?; true end
end
