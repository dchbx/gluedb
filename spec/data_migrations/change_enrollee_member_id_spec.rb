require "rails_helper"
require File.join(Rails.root,"app","data_migrations","change_enrollee_member_id")

describe ChangeEnrolleeMemberId, dbclean: :after_each do 
  let(:given_task_name) { "change_enrollee_member_id" }
  let(:policy) { FactoryGirl.create(:policy) }
  let(:enrollee) { policy.enrollees.first }
  let(:old_hbx_id) {enrollee.m_id}
  let(:new_member_id) { "123456" }
  subject { ChangeEnrolleeMemberId.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "update the member ID" do 

    before(:each) do 
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy.eg_id)
      allow(ENV).to receive(:[]).with("old_hbx_id").and_return(old_hbx_id)
      allow(ENV).to receive(:[]).with("new_hbx_id").and_return(new_member_id)
    end

    it 'should change the member id' do 
      subject.migrate
      enrollee.reload
      expect(enrollee.m_id).not_to eq old_hbx_id
      expect(enrollee.m_id).to eq new_member_id
    end 
  end
end