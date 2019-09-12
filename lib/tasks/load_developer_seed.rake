namespace :developer do
  desc "Load Seed Data for Developers"
  task :load_seed => [
    "developer:load_people",
    "developer:load_users",
    "developer:load_plans",
    "developer:load_policies",
    "developer:load_transmissions_transactions",
    "developer:load_legacy_cv_transactions"
  ] do
    puts("Developer seed load complete.")
  end
end
