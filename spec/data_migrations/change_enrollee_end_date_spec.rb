require "rails_helper"
require File.join(Rails.root,"app","data_migrations","change_enrollee_end_date")

describe ChangeEnrolleeEndDate, dbclean: :after_each do 
  let(:given_task_name) { "change_enrollee_end_date" }
  let(:policy) { FactoryGirl.create(:policy) }
  let (:enrollees) { policy.enrollees }
  subject { ChangeEnrolleeEndDate.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing the end dates for a policy" do 
    before(:each) do 
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy.eg_id)
      allow(ENV).to receive(:[]).with("m_id").and_return(policy.enrollees.first.m_id)
      allow(ENV).to receive(:[]).with("new_end_date").and_return('01/31/2017')
    end

    it "should have an end date" do
      m_id = policy.enrollees.first.m_id
      subject.migrate
      policy.reload
      expect(policy.enrollees.where(m_id: m_id).first.coverage_end).to eq "01/31/2017".to_date
      expect(policy.enrollees.where(m_id: m_id).first.coverage_end.class).to eq Date
    end
    
    it "validate input" do
      allow(ENV).to receive(:[]).with("new_end_date").and_return(nil)

      expect(subject.input_valid?.present?).to eq(false)
    end
    
  end
end