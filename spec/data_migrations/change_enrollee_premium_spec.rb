require "rails_helper"
require File.join(Rails.root,"app","data_migrations","change_enrollee_premium")

describe ChangeEnrolleePremium, dbclean: :after_each do 
  let(:given_task_name) { "change_enrollee_premium" }
  let(:policy) { FactoryGirl.create(:policy) }
  let (:enrollees) { policy.enrollees }
  let (:old_premium){666.66}
  let!(:new_premium) {200}
  subject { ChangeEnrolleePremium.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing the end dates for a policy" do 
    before(:each) do 
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy.eg_id)
      allow(ENV).to receive(:[]).with("m_id").and_return(policy.enrollees.first.m_id)
      allow(ENV).to receive(:[]).with("start_date").and_return(policy.subscriber.coverage_start.strftime('%m/%d/%Y'))
      allow(ENV).to receive(:[]).with("premium").and_return(new_premium)
    end

    it "should change premium" do
      m_id = policy.enrollees.first.m_id
      expect(policy.enrollees.where(m_id: m_id).first.pre_amt).to eq old_premium
      subject.migrate
      policy.reload
      expect(policy.enrollees.where(m_id: m_id).first.pre_amt).to eq new_premium
    end
    
    it "validate input" do
      allow(ENV).to receive(:[]).with("premium").and_return(nil)

      expect(subject.input_valid?.present?).to eq(false)
    end
    
  end
end