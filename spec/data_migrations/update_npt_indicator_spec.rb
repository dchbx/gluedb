require "rails_helper"
require File.join(Rails.root,"app","data_migrations","update_npt_indicator.rb")

describe UpdateNptIndicator, dbclean: :after_each do
  let(:given_task_name) { "update_npt_indicator" }
  let!(:policy) { FactoryGirl.create(:policy, id: 1, eg_id: "123403")}
  let!(:policy2) {FactoryGirl.create(:policy, id: 2, eg_id: "123404")}
  let!(:policy3) {FactoryGirl.create(:policy, id: 3, eg_id: "123405", term_for_np: "true")}
    # From the CSV
  let(:file_name) { "#{Rails.root}/spec/data_migrations/test_npt_indicator_list.csv" }
  subject { UpdateNptIndicator.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "updating policy premium amounts with csv" do
    before(:each) do
      allow(ENV).to receive(:[]).with("csv_file").and_return("true")
      subject.migrate
      policy.reload
      policy2.reload
    end

    it "update NPT indicator for policy" do
      expect(policy2.term_for_np).to eq true
    end

    it "should not update NPT indicator" do
      expect(policy.term_for_np).to eq false
    end
  end

  describe "updating policy npt indicator without csv" do 
    before(:each) do
      allow(ENV).to receive(:[]).with("csv_file").and_return("false")
    end

    it 'update policy npt indicator to false value' do
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy3.id)
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy3.eg_id)
      allow(ENV).to receive(:[]).with("npt_indicator").and_return("false")
      subject.migrate
      policy3.reload
      expect(policy3.term_for_np).to eq false
    end

    it 'update the policy npt_indicator to true value' do
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy2.id)
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy2.eg_id)
      allow(ENV).to receive(:[]).with("npt_indicator").and_return("true")
      subject.migrate
      policy2.reload
      expect(policy2.term_for_np).to eq true
    end
  end
end