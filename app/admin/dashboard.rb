ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Tableau de bord'

  content title: 'Tableau de bord' do
    columns do
      column do
        panel 'Membres' do
          ul do
            li "Total: #{Member.count}"
            li "Changement 30 derniers jours: ..."
          end
        end
      end
      column do
        panel 'Absences cette semaine' do
          ul do
            li para '...'
          end
        end
      end
    end
  end
end
