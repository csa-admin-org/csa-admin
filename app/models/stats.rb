module Stats
  TYPES = %i[
    members
    baskets
    distributions
    halfday_works
  ].freeze

  def self.all(type)
    "Stats::#{type.classify.pluralize}Stat".constantize.all
  end
end
