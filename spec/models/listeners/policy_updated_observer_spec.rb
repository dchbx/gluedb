require 'rails_helper'

describe Listeners::PolicyUpdatedObserver do
  let(:good_plan) { build(:plan, coverage_type: "health", year: Date.today.year)}
  let(:bad_plan) { build(:plan, coverage_type: "dental", year: (Date.today.year - 3.years))}
  let(:good_policy) { FactoryGirl.create(:policy, plan: good_plan) }
  let(:bad_policy) { FactoryGirl.create(:policy, plan: bad_plan) }

  subject { Listeners::PolicyUpdatedObserver}

  before :each do 
    allow(::Listeners::PolicyUpdatedObserver).to receive(:broadcast).and_return(nil)
  end
  
  describe '#notify' do
    it "notifies given the correct plan and type" do 
      allow(Policy).to receive(:where).with(good_policy.eg_id).and_return(good_policy)
      subject.notify(good_policy)
      expect(::Listeners::PolicyUpdatedObserver).to have_received(:broadcast)
    end
    
    it "doesn't notify given the incorrect plan and type" do 
      allow(Policy).to receive(:where).with(bad_policy.eg_id).and_return(bad_policy)
      subject.notify(bad_policy)
      expect(::Listeners::PolicyUpdatedObserver).not_to have_received(:broadcast)
    end
  end

end
