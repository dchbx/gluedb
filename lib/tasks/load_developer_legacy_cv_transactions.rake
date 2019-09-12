namespace :developer do
  desc "Load Demo Legacy CV Transactions"
  task :load_legacy_cv_transactions => :environment do
    policy = Policy.first
    legacy_cv_transaction = policy.legacy_cv_transactions.build
    legacy_cv_transaction.eg_id = policy.eg_id
    legacy_cv_transaction.submitted_at = DateTime.now
    legacy_cv_transaction.action = 'add'
    legacy_cv_transaction.reason = 'initial_enrollment'
    legacy_cv_transaction.location = "fake_folder/folder/" + rand(36**100).to_s(36)
    legacy_cv_transaction.body = FileString.new("fake_folder/folder/fake_transaction_file.text", [*('A'..'Z')].sample(500).join)
    legacy_cv_transaction.save!
    puts("Legacy CV transaction created for first policy.")
  end
end 
