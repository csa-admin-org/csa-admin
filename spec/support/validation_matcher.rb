RSpec::Matchers.define :have_valid do |*attributes|
  match do |record|
    record.validate
    attributes.all? { |attribute| !record.errors.attribute_names.include?(attribute) }
  end

  match_when_negated do |record|
    record.validate
    attributes.all? { |attribute| record.errors.attribute_names.include?(attribute) }
  end
end
