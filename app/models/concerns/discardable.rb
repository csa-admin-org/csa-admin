# frozen_string_literal: true

module Discardable
  extend ActiveSupport::Concern

  included do
    include Discard::Model
  end

  def can_update?
    return false if discarded?

    super
  end

  def can_destroy?
    return false if discarded?

    can_discard? || can_delete?
  end

  def can_discard?
    raise NotImplementedError
  end

  def can_delete?
    raise NotImplementedError
  end

  def destroy
    if can_delete?
      super
    elsif can_discard?
      discard
    else
      raise "Cannot destroy #{self.class.table_name}##{id}"
    end
  end
end
