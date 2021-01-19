require "rails_helper"
require File.join(Rails.root,"app","data_migrations","update_total_responsible_amount.rb")

describe UpdateTotalResponsibleAmount, dbclean: :after_each do
  let(:given_task_name) { "update_total_responsible_amount" }
  let!(:policy) { FactoryGirl.create(:policy, eg_id: "123403")}
  let!(:policy2) {FactoryGirl.create(:policy, eg_id: "123404", tot_res_amt: "1.1")}
    # From the CSV
  let(:file_name) { "#{Rails.root}/spec/data_migrations/test_policy_premium_amounts.csv" }
  subject { UpdateTotalResponsibleAmount.new(given_task_name, double(:current_scope => nil)) }

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

    it "update policy totals" do
      expect(policy.tot_res_amt).to eq 606.34
      expect(policy.pre_amt_tot).to eq 1212.69
      expect(policy.tot_emp_res_amt).to eq 606.35
    end

    it "should not update policy totals" do
      expect(policy2.tot_res_amt).to eq 1.1
    end
  end

  describe "updating policy premium amounts without csv" do 
    before(:each) do
      allow(ENV).to receive(:[]).with("csv_file").and_return("false")
      allow(ENV).to receive(:[]).with("eg_id").and_return(policy.eg_id)
      allow(ENV).to receive(:[]).with("total_responsible_amount").and_return(5)
      allow(ENV).to receive(:[]).with("premium_amount_total").and_return(4)
      allow(ENV).to receive(:[]).with("employer_contribution").and_return(6)
    end

    it 'update policy totals' do
      subject.migrate
      policy.reload
      expect(policy.tot_res_amt).to eq 5
      expect(policy.pre_amt_tot).to eq 4
      expect(policy.tot_emp_res_amt).to eq 6
    end

    it 'update the policy totals  missing total responsible amount' do
      allow(ENV).to receive(:[]).with("total_responsible_amount").and_return('')
      allow(ENV).to receive(:[]).with("employer_contribution").and_return(20.20)
      subject.migrate
      policy.reload
      expect(policy.tot_res_amt).to eq policy.tot_res_amt
      expect(policy.pre_amt_tot).to eq 4 
      expect(policy.tot_emp_res_amt).to eq 20.20
    end

    it 'update the policy totals missing premium amount totals' do
      allow(ENV).to receive(:[]).with("premium_amount_total").and_return('')
      allow(ENV).to receive(:[]).with("employer_contribution").and_return('')
      subject.migrate
      policy.reload
      expect(policy.pre_amt_tot).to eq policy.pre_amt_tot
      expect(policy.tot_emp_res_amt).to eq policy.employer_contribution
    end   

    it 'update the policy totals with non numbers' do
      subject.migrate
      policy.reload
      expect(policy.pre_amt_tot).to eq 4 
    end
  end
end