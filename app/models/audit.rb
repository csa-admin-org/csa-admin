class Audit < ApplicationRecord
  belongs_to :session
  belongs_to :auditable, polymorphic: true
end
