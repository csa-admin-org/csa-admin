class MemberCount
  include ActiveModel::Model

  MEMBER_STATES = %i[pending waiting active support inactive]
  MEMBERSHIP_STATES = %i[trial current future]

  def self.all
    member_states = MEMBER_STATES.dup
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
