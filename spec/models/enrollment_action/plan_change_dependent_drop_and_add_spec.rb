require "rails_helper"

describe EnrollmentAction::PlanChangeDependentDropAndAdd, "given an enrollment even set that:
- has two enrollments
- the first enrollment is a cancel or term for Plan A
- the second enrollment is a start for Plan B
- the second enrollment has some of the same members as the first enrollment and some different members, but the same subscriber" do

  let(:carrier) { instance_double(Carrier, :id => 1) }
  let(:plan) { instance_double(Plan, :id => 1, :carrier_id => carrier.id) }
  let(:plan_2) { instance_double(Plan, :id => 2, :carrier_id => carrier.id)}

  let(:member_ids_1) { [1,2,3] }
  let(:member_ids_2) { [1,2,4] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan_2, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::PlanChangeDependentDropAndAdd }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end

describe EnrollmentAction::DependentDropAndAdd, "given a qualified enrollment set, being persisted", :dbclean => :after_each do 
  let(:existing_benefit) { instance_double(Openhbx::Cv2::EnrolleeBenefit, begin_date: "20140304", premium_amount: "100.11")}
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: "1") }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: "2", :person_relationships => [member_relationship_spouse]) }
  let(:member_drop) { instance_double(Openhbx::Cv2::EnrolleeMember, id: '3') }
  let(:benefit_drop) { instance_double(Openhbx::Cv2::EnrolleeBenefit, end_date: "20140304")}
  let(:benefit_add) { instance_double(Openhbx::Cv2::EnrolleeBenefit, begin_date: "20140304", premium_amount: "100.11")}
  let(:member_relationship) { instance_double(Openhbx::Cv2::PersonRelationship, subject_individual: "blah#1", relationship_uri: "blah#child", object_individual: "blah#4")}
  let(:member_relationship_spouse) { instance_double(Openhbx::Cv2::PersonRelationship, subject_individual: "blah#1", relationship_uri: "blah#spouse", object_individual: "blah#2")}
  let(:member_new) { instance_double(Openhbx::Cv2::EnrolleeMember, id: '4', :person_relationships => [member_relationship]) }

  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary, :benefit => existing_benefit, :is_subscriber => true) }
  let(:enrollee_secondary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_secondary, :benefit => existing_benefit, :is_subscriber => false) }
  let(:enrollee_drop) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_drop, :benefit => benefit_drop, :is_subscriber => false) }
  let(:enrollee_new) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_new, :benefit => benefit_add, :is_subscriber => false) }

  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary, enrollee_drop])}
  let(:shop_market) { nil }
  let(:individual_market) { instance_double(Openhbx::Cv2::PolicyEnrollmentIndividualMarket, :is_carrier_to_bill => true, :applied_aptc_amount => "23.45" ) }
  let(:new_policy_enrollment) { instance_double(Openhbx::Cv2::PolicyEnrollment, 
                                                :premium_total_amount => "123.45", 
                                                :total_responsible_amount => "100.00", 
                                                :shop_market => shop_market, 
                                                :individual_market => individual_market,
                                                :rating_area => "DC",
                                                :plan => cv_plan )}
  let(:new_eg_id) { (policy.eg_id.to_i + 10).to_s }
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :id => new_eg_id, :enrollees => [enrollee_primary, enrollee_secondary, enrollee_new], :policy_enrollment => new_policy_enrollment) }
  let(:carrier) { instance_double(Carrier, :id => 1) }
  let(:plan) { FactoryGirl.create(:plan) }
  let(:plan_2) { FactoryGirl.create(:plan) }
  let(:cv_plan) { instance_double(Openhbx::Cv2::PlanLink, :id => plan_2.hios_plan_id, :alias_ids => "alias_id" )}
  let(:policy) { FactoryGirl.create(:policy)}
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:secondary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:new_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:dependent_add_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => plan_2,
    :all_member_ids => [1,2,4],
    :hbx_enrollment_id => 3
    ) }
  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => terminated_policy_cv,
    :existing_policy => policy,
    :all_member_ids => [1,2,3]
    ) }
  let(:policy_updater_drop) { ExternalEvents::ExternalPolicyMemberDrop.new(policy,terminated_policy_cv,[3]) }
  let(:policy_updater_add) { ExternalEvents::ExternalPolicy.new(new_policy_cv,plan_2,false) }

  subject do
    EnrollmentAction::PlanChangeDependentDropAndAdd.new(dependent_drop_event, dependent_add_event)
  end

  it 'should drop the dependent' do 

    policy.enrollees << Enrollee.new(:m_id => "3", :coverage_start => policy.policy_start, :rel_code => "child")

    allow(policy).to receive(:save).and_return(true)
    allow(ExternalEvents::ExternalPolicyMemberDrop).to receive(:new).with(dependent_drop_event.existing_policy, dependent_drop_event.policy_cv, [3]).and_return(policy_updater_drop)
    allow(policy_updater_drop).to receive(:use_totals_from).with(new_policy_cv)
    allow(policy_updater_drop).to receive(:persist).and_return(true)
    policy_updater_drop.term_enrollee(policy_updater_drop.policy_to_update,policy.enrollees.detect{|en| en.m_id = policy_updater_drop.dropped_member_ids.first.to_s})
    expect(policy.enrollees.detect{|en| en.m_id == '3'}.coverage_end).not_to eq nil
  end

  it 'should generate a new policy with the new enrollee' do 
    allow(enrollee_primary).to receive(:subscriber?).and_return(enrollee_primary.is_subscriber)
    allow(enrollee_secondary).to receive(:subscriber?).and_return(enrollee_secondary.is_subscriber)
    allow(enrollee_new).to receive(:subscriber?).and_return(enrollee_new.is_subscriber)
    allow(policy_updater_add.policy_node).to receive(:responsible_party).and_return(nil)

    policy_updater_add.persist
    expect(policy_updater_add.policy_node.id).to eq(new_eg_id)
    node_policy = Policy.where(:eg_id => policy_updater_add.policy_node.id).first
    node_policy.reload
    expect(node_policy.enrollees.map(&:m_id)).to eq(['1','2','4'])
  end  
end