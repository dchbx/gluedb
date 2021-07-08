require "rails_helper"


describe "policies/generate_tax_document_form.html.haml", :dbclean => :after_each do

  context "policy with responsible party" do
    let(:policy) { FactoryGirl.create(:policy) }
    let(:person) { FactoryGirl.create(:person) }

    before do
      allow(policy).to receive(:has_responsible_person?).and_return(true)
      view.instance_variable_set(:@policy, policy)
      view.instance_variable_set(:@person, person)
      render :template => "policies/generate_tax_document_form"
    end

    # it "should have SSN and DOB fields" do
    #   expect(rendered).to have_content("Responsible Party")
    #   expect(rendered).to have_content(/SSN/i)
    #   expect(rendered).to have_content(/Dob/i)
    # end
  end
end
