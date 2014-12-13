ActiveAdmin.register Member do
  menu priority: 2

  index do
    selectable_column
    # id_column
    column :name do |member|
      link_to member.name, member
    end
    column :emails
    column :phones
    column :distribution, sortable: :distribution_id
    actions
  end

  filter :name
  filter :emails
  filter :address
  filter :distribution
  filter :zip, as: :select, collection: -> { Member.pluck(:zip).uniq.compact.sort }
  filter :created_at

  controller do
    def resource
      Member.find_by(token: params[:id])
    end
  end

  config.per_page = 150
end
