RSpec::Matchers.define :have_valid do |*attributes|
  match do |record, _negated = false|
    record.validate
    attributes.all? { |attribute| !record.errors.keys.include?(attribute) }
  end

  match_when_negated do |record, _negated = false|
    record.validate
    attributes.all? { |attribute| record.errors.keys.include?(attribute) }
  end
end
