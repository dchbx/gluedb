require "rails_helper"

describe ExternalEvents::ExternalPolicyMemberAdd, "given:
- an IVL policy to change
- an IVL policy cv
- a list of add member ids
- with change in aptc
", dbclean: :after_each do

  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:source_premium_total) { "56.78" }
  let(:source_tot_res_amt) { "123.45" }
  let(:source_emp_res_amt) { "98.76" }
  let(:source_ivl_assistance_amount) { "34.21" }
  let(:member_begin) { Date.new(2019,01,01) }
  let(:new_member_begin) { Date.new(2019,02,1) }

  let(:source_event_xml) { <<-EVENTXML
  <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
  <header>
    <hbx_id>29035</hbx_id>
    <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
  </header>
  <event>
    <body>
      <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
        <affected_members>
          <affected_member>
            <member>
              <id><id>1</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190101</begin_date>
            </benefit>
          </affected_member>
          <affected_member>
            <member>
              <id><id>2</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190101</begin_date>
               <end_date>20190131</end_date>
            </benefit>
          </affected_member>
           <affected_member>
            <member>
              <id><id>3</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190201</begin_date>
            </benefit>
          </affected_member>
        </affected_members>
        <enrollment xmlns="http://openhbx.org/api/terms/1.0">
          <policy>
            <id>
              <id>123</id>
            </id>
          <enrollees>
            <enrollee>
              <member>
                <id><id>1</id></id>
              </member>
              <benefit>
                <premium_amount>111.11</premium_amount>
                <begin_date>2019101</begin_date>
              </benefit>
            </enrollee>
            <enrollee>
              <member>
                <id><id>2</id></id>
              </member>
              <benefit>
                <premium_amount>222.22</premium_amount>
                 <begin_date>20190101</begin_date>
                <end_date></end_date>
              </benefit>
            </enrollee>
            <enrollee>
              <member>
                <id><id>3</id></id>
              </member>
              <benefit>
                <premium_amount>222.22</premium_amount>
                 <begin_date>20190201</begin_date>
                <end_date></end_date>
              </benefit>
            </enrollee>
          </enrollees>
          <enrollment>
          <individual_market>
            <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
            <applied_aptc_amount>100.00</applied_aptc_amount>
          </individual_market>
          <premium_total_amount>56.78</premium_total_amount>
          <total_responsible_amount>123.45</total_responsible_amount>
          </enrollment>
          </policy>
        </enrollment>
        </enrollment_event_body>
    </body>
  </event>
</enrollment_event>

  EVENTXML
  }

  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:policy) { FactoryGirl.create(:policy) }
  let!(:enrollees) do
    enrollees = policy.enrollees
    enrollees.update_all(coverage_start: Date.new(2019,1,1), coverage_end: nil)
    enrollees
  end

  let :action do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
  end

  before :each do
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy).and_return(true)
    drop = ExternalEvents::ExternalPolicyMemberAdd.new(policy, action.policy_cv, ["3"])
    drop.persist
    policy.reload
  end

  context "IVL policy with mid year aptc change" do
    it "should create aptc_credits table for policy" do
      expect(policy.aptc_credits.count).to eql(2)
      expect(policy.aptc_credits.where(start_on: member_begin).count).to eql(1)
      expect(policy.aptc_credits.where(start_on: new_member_begin).count).to eql(1)
    end
  end
end

describe ExternalEvents::ExternalPolicyMemberAdd, "given:
- an IVL policy to change
- an IVL policy cv
- a list of add member ids
- with no change in aptc
", dbclean: :after_each do

  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:source_premium_total) { "56.78" }
  let(:source_tot_res_amt) { "123.45" }
  let(:source_emp_res_amt) { "98.76" }
  let(:source_ivl_assistance_amount) { "34.21" }
  let(:member_begin) { Date.new(2019,01,01) }
  let(:new_member_begin) { Date.new(2019,02,1) }

  let(:source_event_xml) { <<-EVENTXML
  <enrollment_event xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns='http://openhbx.org/api/terms/1.0'>
  <header>
    <hbx_id>29035</hbx_id>
    <submitted_timestamp>2016-11-08T17:44:49</submitted_timestamp>
  </header>
  <event>
    <body>
      <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
        <affected_members>
          <affected_member>
            <member>
              <id><id>1</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190101</begin_date>
            </benefit>
          </affected_member>
          <affected_member>
            <member>
              <id><id>2</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190101</begin_date>
               <end_date>20190131</end_date>
            </benefit>
          </affected_member>
           <affected_member>
            <member>
              <id><id>3</id></id>
            </member>
            <benefit>
              <premium_amount>465.13</premium_amount>
              <begin_date>20190201</begin_date>
            </benefit>
          </affected_member>
        </affected_members>
        <enrollment xmlns="http://openhbx.org/api/terms/1.0">
          <policy>
            <id>
              <id>123</id>
            </id>
          <enrollees>
            <enrollee>
              <member>
                <id><id>1</id></id>
              </member>
              <benefit>
                <premium_amount>111.11</premium_amount>
                <begin_date>2019101</begin_date>
              </benefit>
            </enrollee>
            <enrollee>
              <member>
                <id><id>2</id></id>
              </member>
              <benefit>
                <premium_amount>222.22</premium_amount>
                 <begin_date>20190101</begin_date>
                <end_date></end_date>
              </benefit>
            </enrollee>
            <enrollee>
              <member>
                <id><id>3</id></id>
              </member>
              <benefit>
                <premium_amount>222.22</premium_amount>
                 <begin_date>20190201</begin_date>
                <end_date></end_date>
              </benefit>
            </enrollee>
          </enrollees>
          <enrollment>
          <individual_market>
            <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
            <applied_aptc_amount>100.00</applied_aptc_amount>
          </individual_market>
          <premium_total_amount>56.78</premium_total_amount>
          <total_responsible_amount>123.45</total_responsible_amount>
          </enrollment>
          </policy>
        </enrollment>
        </enrollment_event_body>
    </body>
  </event>
</enrollment_event>

  EVENTXML
  }

  let(:m_tag) { double('m_tag') }
  let(:t_stamp) { double('t_stamp') }
  let(:headers) { double('headers') }
  let(:responder) { instance_double('::ExternalEvents::EventResponder') }
  let(:policy) { FactoryGirl.create(:policy) }
  let!(:enrollees) do
    enrollees = policy.enrollees
    enrollees.update_all(coverage_start: Date.new(2019,1,1), coverage_end: nil)
    policy.update_attributes(applied_aptc: 100.00)
    enrollees
  end

  let :action do
    ::ExternalEvents::EnrollmentEventNotification.new responder, m_tag, t_stamp, source_event_xml, headers
  end

  before :each do
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy).and_return(true)
    drop = ExternalEvents::ExternalPolicyMemberAdd.new(policy, action.policy_cv, ["3"])
    drop.persist
    policy.reload
  end

  context "IVL policy with no mid year aptc change" do
    it "should not create aptc_credits table for policy" do
      expect(policy.aptc_credits.count).to eql(0)
    end
  end
end