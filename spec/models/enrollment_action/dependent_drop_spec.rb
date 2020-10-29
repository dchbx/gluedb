require "rails_helper"

describe EnrollmentAction::DependentDrop, "given an enrollment event set that:
- has two enrollments
- the first enrollment is a termination of a member for for plan A
- the second enrollment is a start with one less member for plan A
- the second enrollment has less members" do

  let(:plan) { instance_double(Plan, :id => 1) }
  let(:different_plan) { instance_double(Plan, :id => 2) }

  let(:member_ids_1) { [1,2,3] }
  let(:member_ids_2) { [1,2] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_3) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_4) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => different_plan, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }
  let(:non_qualifying_event_set_1) { [event_2, event_3] } # Same members, meaning no one was dropped
  let(:non_qualifying_event_set_2) { [event_1, event_4] } # Different plans. We are only dropping member, not changing plans

  subject { EnrollmentAction::DependentDrop }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end

  it "does not qualify because it has different plans" do
    expect(subject.qualifies?(non_qualifying_event_set_2)).to be_falsey
  end

  it "does not qualify because no members were dropped" do
    expect(subject.qualifies?(non_qualifying_event_set_1)).to be_falsey
  end

  it "does not qualify because chunk contains only one event" do
    expect(subject.qualifies?(event_set.take(1))).to be_falsey
  end
end

describe EnrollmentAction::DependentDrop, "given a qualified enrollment set, being persisted" do
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:member_drop) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:carrier) { instance_double(Carrier, :renewal_dependent_drop_transmitted_as_renewal => true) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [member_primary, member_secondary, member_drop])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [member_primary, member_secondary]) }
  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1,2,3], carrier: carrier) }
  let(:active_policy) { instance_double(Policy) }

  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => plan,
    :all_member_ids => [1,2],
    :hbx_enrollment_id => 1
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => terminated_policy_cv,
    :existing_policy => policy,
    :all_member_ids => [1,2,3]
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberDrop) }

  subject do
    EnrollmentAction::DependentDrop.new(termination_event, dependent_drop_event)
  end

  before :each do

    allow(policy).to receive(:save).and_return(true)
    allow(ExternalEvents::ExternalPolicyMemberDrop).to receive(:new).with(termination_event.existing_policy, termination_event.policy_cv, [3]).and_return(policy_updater)
    allow(policy_updater).to receive(:use_totals_from).with(new_policy_cv)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(dependent_drop_event).and_return([active_policy])
    allow(dependent_drop_event).to receive(:dep_add_or_drop_to_renewal_policy?).with(active_policy, policy).and_return(false)
  end

  it "uses the xml from the new enrollment for totals" do
    expect(policy_updater).to receive(:use_totals_from).with(new_policy_cv)
    subject.persist
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end
end


describe EnrollmentAction::DependentDrop, "given a qualified enrollment set, being published" do
  let(:amqp_connection) { double }
  let(:termination_event_xml) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollee_primary) { double(:m_id => 1, :coverage_start => :one_month_ago) }
  let(:enrollee_new) { double(:m_id => 2, :coverage_start => :one_month_ago) }
  let(:carrier) { instance_double(Carrier, :renewal_dependent_drop_transmitted_as_renewal => true) }
  let(:plan) { instance_double(Plan, :id => 1, ) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary, enrollee_new], :eg_id => 1, carrier: carrier) }
  let(:active_policy) { instance_double(Policy) }

  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_xml => event_xml,
    :all_member_ids => [1,2],
    :hbx_enrollment_id => 2,
    :employer_hbx_id => 1,
    :existing_policy => policy,
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :event_xml => termination_event_xml,
    :all_member_ids => [1,2,3],
    :event_responder => event_responder,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 3
  ) }
  let(:action_helper_result_xml) { double }

  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    allow(action_publish_helper).to receive(:set_policy_id).with(1).and_return(true)
    allow(action_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    allow(action_publish_helper).to receive(:filter_affected_members).with([3]).and_return(true)
    allow(action_publish_helper).to receive(:replace_premium_totals).with(event_xml)
    allow(action_publish_helper).to receive(:keep_member_ends).with([3])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    allow(action_publish_helper).to receive(:swap_qualifying_event).with(event_xml)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(dependent_drop_event).and_return([active_policy])
    allow(dependent_drop_event).to receive(:dep_add_or_drop_to_renewal_policy?).with(active_policy, policy).and_return(false)
  end

  subject do
    EnrollmentAction::DependentDrop.new(termination_event, dependent_drop_event)
  end

  it "publishes an event of type drop dependents" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    subject.publish
  end

  it "sets member start dates" do
    expect(action_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    subject.publish
  end

  it "filter affected members on the dependent drop" do
    expect(action_publish_helper).to receive(:filter_affected_members).with([3]).and_return(true)
    subject.publish
  end

  it "corrects premium totals on the dependent drop" do
    expect(action_publish_helper).to receive(:replace_premium_totals).with(event_xml)
    subject.publish
  end

  it "keep dropped member end dates before publishing" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([3])
    subject.publish
  end

  it "copies the correct qualifying event" do
    expect(action_publish_helper).to receive(:swap_qualifying_event).with(event_xml)
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end

  it "publishes an event of auto renew event drop dependents on renewal policy" do
    subject.dep_drop_from_renewal = true
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(dependent_drop_event).to receive(:dep_add_or_drop_to_renewal_policy?).with(active_policy, policy).and_return(true)
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_drop_event.hbx_enrollment_id, dependent_drop_event.employer_hbx_id)
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew")
    subject.publish
  end
end

describe "given renewal event, dependent drop from IVL renewal policy", :dbclean => :after_each do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:kind) { 'individual' }
  let(:carrier) { Carrier.create!(:renewal_dependent_drop_transmitted_as_renewal => true) }
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let(:plan2) { Plan.create!(:name => "test_plan", carrier_id: carrier_id, :coverage_type => "health", year: Date.today.next_year.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:dep2) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:prim_coverage_start) { Date.today.next_year.beginning_of_year }
  let(:dep_coverage_start) { Date.today.next_year.beginning_of_year }
  let(:active_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_year, coverage_end: '')}
  let(:active_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: Date.today.beginning_of_month,)}
  let(:active_enrollee3) { Enrollee.new(m_id: dep2.authority_member.hbx_member_id, rel_code: 'child', coverage_start: Date.today.beginning_of_month, coverage_end: Date.today.beginning_of_month,)}
  let(:renewal_enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: prim_coverage_start, coverage_end: '')}
  let(:renewal_enrollee2) { Enrollee.new(m_id: dep.authority_member.hbx_member_id, rel_code: 'child', coverage_start: dep_coverage_start, coverage_end: '')}
  let!(:active_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: eg_id, hbx_enrollment_ids: ["123"], carrier_id: carrier_id, plan: active_plan, carrier: carrier, coverage_start: Date.today.beginning_of_month, coverage_end: nil, kind: kind)
    policy.update_attributes(enrollees: [active_enrollee1, active_enrollee2, active_enrollee3])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy =  FactoryGirl.create(:policy, enrollment_group_id: 2, carrier_id: carrier_id, plan: plan, carrier: carrier, coverage_start: Date.today.next_year.beginning_of_year , coverage_end: nil, kind: kind,)
    policy.update_attributes(enrollees: [renewal_enrollee1, renewal_enrollee2], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let(:dependent_add_xml) { <<-EVENTXML
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
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>1234</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
            <plan>
               <id>
                  <id>#{plan.hios_plan_id}</id>
               </id>
               <name>BluePreferred PPO Standard Platinum $0</name>
               <active_year>2021</active_year>
               <is_dental_only>false</is_dental_only>
               <carrier>
                 <id>
                   <id>#{carrier.hbx_carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
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
  let(:termination_xml) { <<-EVENTXML
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
         </affected_members>
         <enrollment xmlns="http://openhbx.org/api/terms/1.0">
           <policy>
             <id>
               <id>123</id>
             </id>
           <enrollees>
             <enrollee>
               <member>
                 <id><id>#{primary.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>true</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</end_date>
               </benefit>
             </enrollee>
             <enrollee>
               <member>
                 <id><id>#{dep.authority_member.hbx_member_id}</id></id>
               </member>
               <is_subscriber>false</is_subscriber>
               <benefit>
                 <premium_amount>111.11</premium_amount>
                 <begin_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</begin_date>
                 <end_date>#{Date.today.next_year.beginning_of_year.strftime("%Y%m%d")}</end_date>
               </benefit>
             </enrollee>
           </enrollees>
           <enrollment>
            <plan>
               <id>
                  <id>#{plan.hios_plan_id}</id>
               </id>
               <name>BluePreferred PPO Standard Platinum $0</name>
               <active_year>2021</active_year>
               <is_dental_only>false</is_dental_only>
               <carrier>
                 <id>
                   <id>#{carrier.hbx_carrier_id}</id>
                 </id>
                 <name>CareFirst</name>
               </carrier>
               <metal_level>urn:openhbx:terms:v1:plan_metal_level#platinum</metal_level>
               <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
               <ehb_percent>99.64</ehb_percent>
             </plan>
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
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let :termination_event do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, termination_xml, headers
  end
  let :dependent_add_event do
    ::ExternalEvents::EnrollmentEventNotification.new event_responder, m_tag, t_stamp, dependent_add_xml, headers
  end
  subject do
    EnrollmentAction::DependentDrop.new(termination_event, dependent_add_event)
  end
  let(:policy) { instance_double(Policy) }
  let(:connection) { double }
  let(:event_broadcaster) do
    instance_double(Amqp::EventBroadcaster)
  end

  context "#qualifies #persist #publish" do
    before do
      allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast)
    end

    it "should cancel existing renewal, creates the new renewal policy without drop depenedent and trigger auto renew event on new renewal policy" do
      expect(EnrollmentAction::DependentDrop.qualifies?([termination_event, dependent_add_event])).to be_truthy

      expect(subject.persist).to be_truthy
      renewal_policy.reload
      expect(renewal_policy.canceled?).to be_truthy
      expect(Policy.where(hbx_enrollment_ids: dependent_add_event.hbx_enrollment_id).count).to eq 1

      expect_any_instance_of(EnrollmentAction::ActionPublishHelper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew")
      subject.publish
    end
  end
end
