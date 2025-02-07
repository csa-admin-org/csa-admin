# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :attachable, polymorphic: true

  has_one_attached :file

  validates :file, presence: true
end
