require 'rails_helper'

 RSpec.describe LegacyCvTransactionsController, dbclean: :after_each do
  describe "GET #show" do
    let(:policy) { FactoryGirl.create(:policy) }
    let!(:legacy_cv_transaction) do
      transaction = policy.legacy_cv_transactions.build
      transaction.submitted_at = DateTime.now
      transaction.location = "fake_folder/folder/"
      transaction.body = FileString.new("fake_folder/folder/fake_transaction_file.text", [*('A'..'Z')].sample(50).join)
      transaction.save!
      transaction
    end

     context "logged in" do
      login_user

       it "succeeds" do
        get :show, id: legacy_cv_transaction.id
        expect(response).to have_http_status(:success)
      end
    end

     context "not logged in as admin" do
      before(:each) do
        user = FactoryGirl.create(:user)
        sign_in(user)
      end

       it "fails" do
        get :show, id: legacy_cv_transaction.id
        expect(response).not_to have_http_status(:success)
      end
    end

     context "not logged in" do
      it "fails" do
        get :show, id: legacy_cv_transaction.id
        expect(response).not_to have_http_status(:success)
      end
    end
  end

   describe "GET #index" do
    context "logged in" do
      login_user

       it "succeeds" do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

     context "not logged in as admin" do
      before(:each) do
        user = FactoryGirl.create(:user)
        sign_in(user)
      end

       it "fails" do
        get :index
        expect(response).not_to have_http_status(:success)
      end
    end

     context "not logged in" do
      it "fails" do
        get :index
        expect(response).not_to have_http_status(:success)
      end
    end
  end
end
