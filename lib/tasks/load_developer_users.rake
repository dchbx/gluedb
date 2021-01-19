namespace :developer do
  desc "Load Demo Users"
  task :load_users => :environment do
    admin_user = User.create!(
      email: "admin@dc.gov",
      role: "admin",
      password: "Password1!",
      password_confirmation: "Password1!",
      approved: true
    )
    puts("#{User.count} users created.") unless Rails.env.test?
  end
end
