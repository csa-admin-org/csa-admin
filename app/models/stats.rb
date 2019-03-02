module Stats
  TYPES = %i[
    members
    baskets
    depots
    activities
  ].freeze

  def self.all(type)
    "Stats::#{type.classify.pluralize}Stat".constantize.all
  end
end
