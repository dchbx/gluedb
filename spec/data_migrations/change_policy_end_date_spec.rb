require "rails_helper"
require File.join(Rails.root,"app","data_migrations","change_policy_end_date")

describe ChangePolicyEndDate, dbclean: :after_each do 
  let(:given_task_name) { "change_policy_end_date" }
  let(:policy) { FactoryGirl.create(:policy) }
  let (:enrollees) { policy.enrollees }
  let(:end_date) { (policy.policy_start + 2.months).end_of_month}
  subject { ChangePolicyEndDate.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing the end dates for a policy" do 
    before(:each) do 
      allow(ENV).to receive(:[]).with("eg_ids").and_return(policy.eg_id)
      allow(ENV).to receive(:[]).with("end_date").and_return(end_date)
    end

    it "should have an end date" do
      subject.deactivate_enrollees(policy)
      policy.reload
      expect(policy.policy_end).to eq ENV['end_date'].to_date
    end

    it "should alter the aasm state" do
      subject.change_aasm_state(policy)
      policy.reload
      if policy.policy_start == ENV['end_date'].to_date
        expect(policy.aasm_state.downcase).to eq 'canceled'
      elsif policy.policy_start != ENV['end_date'].to_date
        expect(policy.aasm_state.downcase).to eq 'terminated'
      end
    end
  end
end
