namespace :organizations do
  desc "List organizations by when their next fiscal year starts"
  task next_fiscal_year: :environment do
    Organization
      .all
      .group_by { |o| o.next_fiscal_year.range.min }
      .sort
      .each do |date, orgs|
        print "-- #{date} --\n"
        orgs.each do |org|
          print "  #{org.name}\n"
        end
      end
  end
end
