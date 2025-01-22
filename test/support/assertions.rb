# frozen_string_literal: true

module Assertions
  include Minitest::Assertions
  # Checks if an array contains a consecutive sequence of elements
  def assert_contains(full_array, *partial_sequence)
    partial_sequence.flatten!
    msg = -> { diff(full_array, partial_sequence) }
    assert full_array.each_cons(partial_sequence.size).include?(partial_sequence), msg
  end
end
