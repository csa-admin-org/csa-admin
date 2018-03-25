namespace :newsletter do
  desc 'Sync newsletter list'
  task sync_list: :environment do
    ACP.enter_each! { Newsletter.sync_list }
  end
end
