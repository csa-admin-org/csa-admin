# frozen_string_literal: true

module Session::DeletionCode
  extend ActiveSupport::Concern

  def rotate_deletion_code!
    touch(:updated_at)
  end

  def deletion_code
    DeletionCode.generate(self)
  end
end
