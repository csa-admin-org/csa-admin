module Stats
  TYPES = %i[
    members
    baskets
    distributions
    halfdays
  ].freeze

  def self.all(type)
    "Stats::#{type.classify.pluralize}Stat".constantize.all
  end
end
