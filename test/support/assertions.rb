# frozen_string_literal: true

module Assertions
  # Checks if an array contains a consecutive sequence of elements
  def assert_contains(full_array, *partial_sequence)
    partial_sequence.flatten!
    msg ||= "Expected: [\n#{full_array.map(&:inspect).join(",\n")}\n] to contain the sequence [\n#{partial_sequence.map(&:inspect).join(",\n")}\n] consecutively."
    assert full_array.each_cons(partial_sequence.size).include?(partial_sequence), msg
  end
end
