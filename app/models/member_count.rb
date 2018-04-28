class MemberCount
  include ActiveModel::Model

  STATES = %i[pending waiting trial active support inactive]

  def self.all
    states = STATES.dup
    states.delete(:trial) if Current.acp.trial_basket_count.zero?
    states.map { |state| new(state) }
  end

  attr_reader :state

  def initialize(state)
    @state = state
  end

  def title
    I18n.t("states.member.#{@state}").capitalize
  end

  def count
    Member.send(@state).count
  end

  def count_precision
    case @state
    when :active
      sub_count = Member.active.where(salary_basket: true).count
      "(#{sub_count} #{Member.human_attribute_name(:salary_basket).downcase}) "
    end
  end
end
