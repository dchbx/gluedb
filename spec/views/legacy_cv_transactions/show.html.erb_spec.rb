require "rails_helper"

 RSpec.describe "legacy_cv_transactions/show.html.erb" do
  include Devise::TestHelpers
  let(:policy) { FactoryGirl.create(:policy)}
  let(:legacy_cv_transaction) do
    transaction = policy.legacy_cv_transactions.build
    transaction.submitted_at = DateTime.now
    transaction.location = "fake_folder/folder/"
    transaction.body = FileString.new(
      "fake_folder/folder/fake_transaction_file.text",
      [*('A'..'Z')].sample(50).join
    )
    transaction.save!
    transaction
  end
  let(:person) { FactoryGirl.create(:person) }

   before(:each) do
    assign(:legacy_cv_transaction, legacy_cv_transaction)
    assign(:person, person)
  end

   it "should successfully render the template" do
    render template: "legacy_cv_transactions/show"
  end
end
