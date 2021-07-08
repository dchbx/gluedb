require 'rails_helper'

describe PoliciesController, :dbclean => :after_each do

  let(:policy) { FactoryGirl.create(:policy) }
  let(:person) { FactoryGirl.create(:person) }

  before(:each) do
    allow(controller).to receive(:generate_1095A_pdf).and_return("")
    @user = create :user, :admin
    sign_in @user
  end

  describe 'POST generate_tax_document' do

    context "no preview" do
      context "success" do
        before do
          post :generate_tax_document, {person_id: person.id, id: policy.id}.merge(
              {"type" => "original", "void_policy_ids" => "", "npt" => "1", "preview" => "0"})
        end

        it 'redirects to `person_path`' do
          expect(response).to redirect_to(person_path(person))
        end
      end

      context "failure" do
        before do
          allow(controller).to receive(:upload_to_s3).with(an_instance_of(String), an_instance_of(String)).and_return(false)
          post :generate_tax_document, {person_id: person.id, id: policy.id}.merge(
              {"type" => "original", "void_policy_ids" => "", "npt" => "1", "preview" => "0"})
        end

        it 'redirects to `person_path` with status code 500' do
          expect(flash[:error]).to match(/Could not upload file/)
        end
      end
    end

    context "preview" do
      before do
        post :generate_tax_document, {person_id: person.id, id: policy.id}.merge(
            {"type" => "original", "void_policy_ids" => "", "npt" => "1", "preview" => "1"})
      end

      it 'renders `generate_tax_document` template' do
        expect(response).to render_template("generate_tax_document")
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'DELETE delete_local_generated_tax_document' do

    context "success" do
      before do
        allow(controller).to receive(:delete_1095A_pdf).with(an_instance_of(String)).and_return(true)
        delete :delete_local_generated_tax_document, {id: policy.id, person_id: person.id, file_name: "file_name"}
      end

      it 'redirects to `person_path`' do
        expect(response).to redirect_to(person_path(person))
        expect(flash[:notice]).to match(/Deleted the generated 1095A PDF/)
      end
    end

    context "failure" do
      before do
        allow(controller).to receive(:delete_1095A_pdf).with(an_instance_of(String)).and_return(false)
        delete :delete_local_generated_tax_document, {id: policy.id, person_id: person.id, file_name: "file_name"}
      end

      it 'redirects to `person_path`' do
        expect(response).to redirect_to(person_path(person))
        expect(flash[:error]).to match(/Could not delete 1095A PDF/)
      end
    end
  end
end
