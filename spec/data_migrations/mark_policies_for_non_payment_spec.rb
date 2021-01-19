require "rails_helper"
require File.join(Rails.root,"app","data_migrations","mark_policies_for_non_payment")

describe MarkPoliciesForNonPayment, dbclean: :after_each do
  let(:given_task_name) { "mark_policies_for_non_payment" }
  let!(:policy1) { FactoryGirl.create(:policy, aasm_state: "terminated") }
  let!(:policy2) { FactoryGirl.create(:policy, aasm_state: "cancelled") }
  let!(:policy3) { FactoryGirl.create(:policy) }
  subject { MarkPoliciesForNonPayment.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "updating the term_for_np field to be true for terminated policy" do
    before(:each) do
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy1.id)
    end

    it "should initially be set to false" do
      expect(policy1.term_for_np).to eq false
    end

    it "should be set to true after the rake task is complete" do
      subject.migrate
      policy1.reload
      expect(policy1.term_for_np).to eq true
    end
  end

  describe "updating the term_for_np field to be true for cancelled policy" do
    before(:each) do
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy2.id)
    end

    it "should initially be set to false" do
      expect(policy2.term_for_np).to eq false
    end

    it "should be set to true after the rake task is complete" do
      subject.migrate
      policy2.reload
      expect(policy2.term_for_np).to eq true
    end
  end

  describe "ignoring policies that are neither cancelled or termninated" do
    before(:each) do
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy3.id)
    end

    it "should initially be set to false" do
      expect(policy3.term_for_np).to eq false
    end

    it "should remain false after the task is executed" do
      subject.migrate
      policy3.reload
      expect(policy3.term_for_np).to eq false
    end
  end

end