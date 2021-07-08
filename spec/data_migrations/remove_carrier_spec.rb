require "rails_helper"
require File.join(Rails.root,"app","data_migrations","remove_carrier")

describe RemoveCarrier, dbclean: :after_each do
  let(:given_task_name) { "remove_carrier" }
  let(:carrier) { FactoryGirl.create(:carrier) }
  let!(:plan) { FactoryGirl.create(:plan, carrier: carrier)}
  subject { RemoveCarrier.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "deleting plans" do
    before { subject.remove_plans }

    it "should remove the plans" do
      expect(Plan.where(_id: plan._id).first).to be_nil
    end
  end

  describe "deleting carrier" do 
    before(:each) do
      allow(ENV).to receive(:[]).with("abbrev").and_return(carrier.abbrev)
    end

    it "should remove the carrier" do
      abbrev = carrier.abbrev
      expect(carrier.abbrev).to eq abbrev
      subject.remove_carrier
      expect(Carrier.where(abbrev: abbrev).size).to eq 0
    end
  end
end