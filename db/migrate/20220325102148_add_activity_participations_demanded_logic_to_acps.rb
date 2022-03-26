class AddActivityParticipationsDemandedLogicToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :activity_participations_demanded_logic, :text, null: false, default: <<~LIQUID
      {% if member.salary_basket %}
        0
      {% else %}
        {{ membership.baskets | divided_by: membership.full_year_deliveries | times: membership.full_year_activity_participations | round }}
      {% endif %}
    LIQUID
  end
end
