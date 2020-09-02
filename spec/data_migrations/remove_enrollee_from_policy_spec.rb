require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "remove_enrollee_from_policy")

describe RemoveEnrolleeFromPolicy, dbclean: :after_each do 
  let(:given_task_name) { "remove_enrollee_from_policy" }
  let(:policy) { FactoryGirl.create(:policy) }
  let (:enrollees) { policy.enrollees }
  let(:removal_enrollee) { policy.enrollees.sample(1).first }
  subject { RemoveEnrolleeFromPolicy.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing the end dates for a policy" do 
    before(:each) do 
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy.eg_id)
      removal_enrollee.update_attributes(:m_id => '4624327')
      allow(ENV).to receive(:[]).with("m_id").and_return('4624327')
    end

    it "should not have the removal_enrollee" do
      subject.migrate
      policy.reload
      expect(policy.enrollees.include?(removal_enrollee)).to eq false
    end
  end
end