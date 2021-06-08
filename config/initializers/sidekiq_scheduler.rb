# https://github.com/moove-it/sidekiq-scheduler#notes-about-connection-pooling
SidekiqScheduler::Scheduler.instance.rufus_scheduler_options = {
  max_work_threads: 4
}
