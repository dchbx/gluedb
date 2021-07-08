require "rails_helper"
require File.join(Rails.root,"app","data_migrations","merge_two_policies")

describe MergeTwoPolicies, dbclean: :after_each do

  let(:given_task_name) { "merge_two_policies" }
  let(:policy_to_keep) { FactoryGirl.create(:policy) }
  let(:policy_to_keep_enrollees){ policy_to_keep.enrollees  }
  let(:policy_to_remove) { FactoryGirl.create(:policy, tot_res_amt:300, pre_amt_tot:400,tot_emp_res_amt:500,rating_area:"A050", composite_rating_tier:"2") }
  let(:policy_to_remove_enrollees){policy_to_remove.enrollees }
  let(:another_policy_to_remove) { FactoryGirl.create(:policy, tot_res_amt:220, pre_amt_tot:420, tot_emp_res_amt:520,rating_area:"C050", composite_rating_tier:"24") }
  let(:another_policy_to_remove_enrollees){policy_to_remove.enrollees }

  subject { MergeTwoPolicies.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  context 'merge two policies' do 
    before(:each)  do 
      allow(ENV).to receive(:[]).with("policy_to_keep").and_return(policy_to_keep.eg_id)
      allow(ENV).to receive(:[]).with("policy_to_remove").and_return(policy_to_remove.eg_id)
      allow(ENV).to receive(:[]).with("fields_from_policy_to_remove").and_return("tot_res_amt, pre_amt_tot, tot_emp_res_amt, rating_area, composite_rating_tier")
    end
    
    it 'should merge two policies' do
      expected_values = policy_to_keep.hbx_enrollment_ids + policy_to_remove.hbx_enrollment_ids
      subject.migrate
      policy_to_keep.reload
      policy_to_remove.reload
      
      expect(policy_to_keep.tot_res_amt).to eq 300
      expect(policy_to_keep.pre_amt_tot).to eq 400
      expect(policy_to_keep.tot_emp_res_amt).to eq 500
      expect(policy_to_keep.rating_area).to eq "A050"
      expect(policy_to_keep.composite_rating_tier).to eq "2"
      expect(policy_to_keep.enrollees.map(&:m_id)).to eq ['1','2','3','4']
      expect(policy_to_keep.hbx_enrollment_ids).to eq expected_values
      expect(policy_to_remove.hbx_enrollment_ids).to eq ["2 - DO NOT USE"]
      expect(policy_to_remove.eg_id).to eq "2 - DO NOT USE"
    end
  end

  context 'merge another two policies' do 
    before(:each)  do 
      allow(ENV).to receive(:[]).with("policy_to_keep").and_return(policy_to_keep.eg_id)
      allow(ENV).to receive(:[]).with("policy_to_remove").and_return(another_policy_to_remove.eg_id)
      allow(ENV).to receive(:[]).with("fields_from_policy_to_remove").and_return("tot_emp_res_amt, rating_area, composite_rating_tier")
    end
    
    it 'should merge another two policies together ' do
      expected_values = policy_to_keep.hbx_enrollment_ids + another_policy_to_remove.hbx_enrollment_ids
      subject.migrate
      policy_to_keep.reload
      another_policy_to_remove.reload
      
      expect(policy_to_keep.tot_res_amt).to eq 111.11.to_d
      expect(policy_to_keep.pre_amt_tot).to eq 666.66.to_d
      expect(policy_to_keep.tot_emp_res_amt).to eq 520.to_d
      expect(policy_to_keep.rating_area).to eq "C050"
      expect(policy_to_keep.composite_rating_tier).to eq "24"
      expect(policy_to_keep.hbx_enrollment_ids).to eq expected_values
      expect(another_policy_to_remove.hbx_enrollment_ids).to eq ["4 - DO NOT USE"]
      expect(another_policy_to_remove.eg_id).to eq "4 - DO NOT USE"
    end

    it 'should merge other attributes of two policies together' do
          allow(ENV).to receive(:[]).with("fields_from_policy_to_remove").and_return("tot_emp_res_amt")
      expected_values = policy_to_keep.hbx_enrollment_ids + another_policy_to_remove.hbx_enrollment_ids
      subject.migrate
      policy_to_keep.reload
      another_policy_to_remove.reload
      
      expect(policy_to_keep.tot_res_amt).to eq 111.11.to_d
      expect(policy_to_keep.pre_amt_tot).to eq 666.66.to_d
      expect(policy_to_keep.tot_emp_res_amt).to eq 520.to_d
      expect(policy_to_keep.rating_area).to eq "100"
      expect(policy_to_keep.composite_rating_tier).to eq "rspec-mock"
      expect(policy_to_keep.hbx_enrollment_ids).to eq expected_values
      expect(another_policy_to_remove.hbx_enrollment_ids).to eq ["6 - DO NOT USE"]
      expect(another_policy_to_remove.eg_id).to eq "6 - DO NOT USE"
    end
  end
end





