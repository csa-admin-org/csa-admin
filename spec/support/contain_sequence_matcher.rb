# Matcher that tests whether a sequence contains another subsequence.
#
#   expect([1, 2, 3, 4]).to contain_sequence(2, 3)
#   expect([1, 2, 3, 4]).not_to contain_sequence(1, 3)
RSpec::Matchers.define :contain_sequence do |*expected|
  match do |actual|
    matcher = RSpec::Matchers::BuiltIn::Match.new(expected)
    actual.each_cons(expected.length).any? { |x| matcher.matches?(x) }
  end
end
