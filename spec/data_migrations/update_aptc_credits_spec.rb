require "rails_helper"
require File.join(Rails.root,"app","data_migrations","update_aptc_credits.rb")

describe UpdateAptcCredits, dbclean: :after_each do 
  let(:given_task_name) { "update_aptc_credits" }
  let(:policy) { FactoryGirl.create(:policy, applied_aptc:"550", pre_amt_tot:"650",tot_res_amt:"100") }
  let!(:credit) {policy.aptc_credits.create!(start_on:"2/1/2019", end_on:"2/28/2019", pre_amt_tot:"300", tot_res_amt:"100", aptc:"200")}
  let!(:credit1) {policy.aptc_credits.create!(start_on:"3/1/2019", end_on:"6/30/2019", pre_amt_tot:"200", tot_res_amt:"100", aptc:"100")}
  
  subject { UpdateAptcCredits.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing the end dates for a policy", dbclean: :after_each do 
    before(:each) do 
      allow(ENV).to receive(:[]).with("policy_id").and_return("1")
      allow(ENV).to receive(:[]).with("start_on").and_return("6/1/2019")
      allow(ENV).to receive(:[]).with("end_on").and_return("7/30/2018")
      allow(ENV).to receive(:[]).with("pre_amt_tot").and_return("400")
      allow(ENV).to receive(:[]).with("tot_res_amt").and_return("200")
      allow(ENV).to receive(:[]).with("aptc").and_return("200")
      allow(ENV).to receive(:[]).with("delete_credit").and_return(nil)

      policy.enrollees.each{|er| er.update_attributes!(coverage_end:nil)  }
    end

    it 'updates aptc credits with matching start and end dates' do  
      subject.migrate
      policy.reload
      credit.reload
      
      expect(credit.pre_amt_tot).to eq 300
      expect(credit.tot_res_amt).to eq 100
    end

    it 'updates aptc credits with matching start and end dates and finds by policy id' do 
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy.id)

      subject.migrate
      policy.reload
      credit.reload
      
      expect(credit.pre_amt_tot).to eq 300
      expect(credit.tot_res_amt).to eq 100
    end

    it 'finds and updates the end date on a credit with no mathcing end day' do 
      allow(ENV).to receive(:[]).with("end_on").and_return("7/2/2018")

      subject.migrate
      policy.reload
      credit.reload
      
      expect(credit.pre_amt_tot).to eq 300
      expect(credit.tot_res_amt).to eq 100
      expect(credit.end_on).to eq Date.new(2019,2,28)
    end

    it 'finds a matching aptc credit and deletes it' do 
      expect(policy.aptc_credits.count).to eq 2

      allow(ENV).to receive(:[]).with("delete_credit").and_return("true")
      allow(ENV).to receive(:[]).with("start_on").and_return("3/1/2019")

      subject.migrate
      policy.reload

      expect(policy.aptc_credits.count).to eq 1
    end


    it 'finds and updates the end date on a credit with no matching end day' do 
      allow(ENV).to receive(:[]).with("end_on").and_return("5/2/2018")
      allow(ENV).to receive(:[]).with("start_on").and_return("4/2/2018")
      allow(ENV).to receive(:[]).with("aptc").and_return("50")
      policy.enrollees.each{|er| er.update_attributes!(coverage_end:nil)  }

      subject.migrate
      policy.reload
      credit.reload

      expect(credit.pre_amt_tot).to eq 300
      expect(credit.tot_res_amt).to eq 100
      expect(credit.end_on).to eq Date.new(2019,2,28)
      expect(credit.start_on).to eq Date.new(2019,2,1)
    end

    it "updates aptc credits with matching start and end dates and finds by policy id'" do 
      allow(ENV).to receive(:[]).with("policy_id").and_return(policy.id)
      allow(ENV).to receive(:[]).with("end_on").and_return("2/1/2018")
      allow(ENV).to receive(:[]).with("start_on").and_return("4/2/2018")
      allow(ENV).to receive(:[]).with("pre_amt_tot").and_return("200")
      allow(ENV).to receive(:[]).with("tot_res_amt").and_return("100")
      allow(ENV).to receive(:[]).with("aptc").and_return("50")
      allow(ENV).to receive(:[]).with("delete_credit").and_return(nil)

      policy.enrollees.each{|er| er.update_attributes!(coverage_end:nil)  }

      subject.migrate
      policy.reload
      credit.reload

      expect(credit.pre_amt_tot).to eq 300
      expect(credit.tot_res_amt).to eq 100
      expect(credit.aptc).to eq 200
      expect(policy.applied_aptc).to eq 100
      expect(policy.tot_res_amt).to eq policy.pre_amt_tot - policy.applied_aptc

    end
  end
end

describe "Creating new aptc credits", dbclean: :after_each do 
  let(:given_task_name) { "update_aptc_credits" }
  let(:policy) { FactoryGirl.create(:policy, applied_aptc:"250", pre_amt_tot:"350",tot_res_amt:"100") }
  subject { UpdateAptcCredits.new(given_task_name, double(:current_scope => nil)) }

  before(:each) do
    allow(ENV).to receive(:[]).with("policy_id").and_return("1")
    allow(ENV).to receive(:[]).with("start_on").and_return("6/1/2019")
    allow(ENV).to receive(:[]).with("end_on").and_return("7/30/2018")
    allow(ENV).to receive(:[]).with("pre_amt_tot").and_return("400")
    allow(ENV).to receive(:[]).with("tot_res_amt").and_return("200")
    allow(ENV).to receive(:[]).with("aptc").and_return("200")
    allow(ENV).to receive(:[]).with("delete_credit").and_return(nil)
    policy.enrollees.each{|er| er.update_attributes!(coverage_end:nil)  }
  end

  it "should add new aptc credit" do
    expect(policy.aptc_credits.count).to eq 0
    subject.migrate
    policy.reload
    expect(policy.aptc_credits.count).to eq 1
  end

  it "should change the policy credit values after adding new aptc" do
    expect(policy.applied_aptc).to eq 250
    subject.migrate
    policy.reload
    expect(policy.applied_aptc).to eq 200
  end
end
