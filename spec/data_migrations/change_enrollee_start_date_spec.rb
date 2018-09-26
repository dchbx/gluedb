require "rails_helper"
require File.join(Rails.root,"app","data_migrations","change_enrollee_start_date")

describe ChangeEnrolleeStartDate, dbclean: :after_each do 
  let(:given_task_name) { "change_enrollee_start_date" }
  let(:policy) { FactoryGirl.create(:policy) }
  let (:enrollees) { policy.enrollees }
  subject { ChangeEnrolleeStartDate.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing the end dates for a policy" do 
    before(:each) do 
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy.eg_id)
      allow(ENV).to receive(:[]).with("m_id").and_return(policy.enrollees.first.m_id)
      allow(ENV).to receive(:[]).with("enrollee_mongo_id").and_return(policy.enrollees.first.id)
      allow(ENV).to receive(:[]).with("start_date").and_return(policy.subscriber.coverage_start.strftime('%m/%d/%Y'))
      allow(ENV).to receive(:[]).with("new_start_date").and_return('01/31/2017')
    end

    it "should have a new start date" do
      m_id = policy.enrollees.first.m_id
      subject.migrate
      policy.reload
      expect(policy.enrollees.where(m_id: m_id).first.coverage_start).to eq Date.strptime("01/31/2017", "%m/%d/%Y")
    end
    
    it "validate input" do
      allow(ENV).to receive(:[]).with("new_start_date").and_return(nil)

      expect(subject.input_valid?.present?).to eq(false)
    end
    
  end
end