require 'rails_helper'

describe EmployerEvent, :dbclean => :after_each do
  describe 'Employer event with trading partner publishable flag' do

    let!(:plan_year_start_date) { Date.new(2017, 4, 1) }
    let!(:new_plan_year_end_date) { Date.new(2017, 12, 31) }
    let!(:plan_year_end_date) {Date.new(2018, 03, 31)}
    let(:event_name) { "benefit_coverage_period_terminated_voluntary" }
    let(:event_time) { Time.now }
    let!(:employer) { FactoryGirl.create(:employer)}
    let!(:plan_year) { FactoryGirl.create(:plan_year, start_date: plan_year_start_date, end_date: plan_year_end_date, employer_id: employer.id)}

    let(:employer_event_xml) do
      <<-XML_CODE
      <organization xmlns="http://openhbx.org/api/terms/1.0">
      <id>
      <id>#{employer.hbx_id}</id>
      </id>
      <name>#{employer.name}</name>
      <dba>#{employer.dba}</name>
      <fein>#{employer.fein}</fein>
      <employer_profile>
        <plan_years>
          <plan_year>
            <plan_year_start>#{plan_year_start_date.strftime("%Y%m%d")}</plan_year_start>
            <plan_year_end>#{new_plan_year_end_date.strftime("%Y%m%d")}</plan_year_end>
          </plan_year>
        </plan_years>
      </employer_profile>
      </organization>
      XML_CODE
    end

    before do
      employer.plan_years << plan_year
      EmployerEvent.store_and_yield_deleted(employer.hbx_id, event_name, event_time, employer_event_xml, trading_partner_publishable)
    end

    context "with trading_partner_publishable = true" do

      let(:trading_partner_publishable) { true }

      it "should create employer event"  do
        expect(EmployerEvent.all.count).to eq 1
      end

      it "should update employer plan year end date." do
        plan_year.reload
        expect(plan_year.end_date).to eql new_plan_year_end_date
      end
    end

    context "with trading_partner_publishable = false" do

      let(:trading_partner_publishable) { false }

      it "should not create employer event."  do
        expect(EmployerEvent.all.count).to eq 0
      end

      it "should update employer plan year end date"  do
        plan_year.reload
        expect(plan_year.end_date).to eql new_plan_year_end_date
      end
    end
  end
end
