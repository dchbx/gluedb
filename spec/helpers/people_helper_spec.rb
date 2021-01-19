require 'rails_helper'

RSpec.describe PeopleHelper, :type => :helper do

  describe "show coverall for sponsor on coverall policies" do
    let(:policy) { FactoryGirl.create(:policy, kind: "coverall") }

    context "current year policy" do
      let(:subscriber) { FactoryGirl.build(:enrollee, :coverage_start => Date.new(Date.today.year,01,01)) }
      before do
        allow(policy).to receive(:subscriber).and_return(subscriber)
      end

      it "returns Coverall" do
        expect(helper.policy_sponsor(policy)).to eq("Coverall")
      end
    end
  end
end
