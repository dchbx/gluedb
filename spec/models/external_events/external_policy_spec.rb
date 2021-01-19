require "rails_helper"

describe ExternalEvents::ExternalPolicy, "given:
- a cv policy object
- a plan
" do

  after :each do
    Plan.where({}).delete_all
    Policy.where({}).delete_all
  end

  let(:plan_cv) { instance_double(Openhbx::Cv2::PlanLink, :alias_ids => alias_ids) }
  let!(:policy_enrollment) { instance_double(Openhbx::Cv2::PolicyEnrollment, :rating_area => rating_area, :plan => plan_cv, :shop_market => shop_market) }
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment, :enrollees =>[enrollees1, enrollees2]) }
  let(:member1) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => subscriber_xml_id, :person_relationships => []) }
  let(:member2) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => dependent_xml_id, :person_relationships => [relationship]) }
  let(:relationship) do
    instance_double(Openhbx::Cv2::PersonRelationship,
      subject_individual: dependent_xml_id,
      object_individual: subscriber_xml_id,
      relationship_uri: dependent_relationship_uri
    )
  end

  let(:dependent_relationship_uri) { "urn:openhbx:terms:v1:individual_relationship#spouse" }

  let(:subscriber_xml_id) { "urn:whaTEVER#subscriber_id" }
  let(:dependent_xml_id) { "urn:whaTEVER#dependent_id" }
  let(:enrollees1) { instance_double(Openhbx::Cv2::Enrollee, subscriber?: true, member: member1)}
  let(:enrollees2) { instance_double(Openhbx::Cv2::Enrollee, subscriber?: false, member: member2)}
  let(:plan) { instance_double(Plan) }
  let(:rating_area) { nil }
  let(:alias_ids) { nil }
  let(:shop_market) { nil }

  subject { ExternalEvents::ExternalPolicy.new(policy_cv, plan) }

  describe "and the policy cv has a rating area" do
    let(:rating_area) { "RATING AREA VALUE" }
    it "has the rating area" do
      expect(subject.extract_rating_details[:rating_area]).to eq rating_area
    end
  end

  describe "and the policy cv has carrier specific plan id" do
    let(:carrier_specific_plan_id) { "THE SPECIAL CARRIER PLAN ID" }
    let(:alias_ids) { [carrier_specific_plan_id] }

    it "has the carrier_specific_plan_id" do
      expect(subject.extract_rating_details[:carrier_specific_plan_id]).to eq carrier_specific_plan_id
    end
  end

  describe "determining relationships" do
    describe "given a domestic partner relationship" do
      let(:dependent_relationship_uri) { "urn:openhbx:terms:v1:individual_relationship#domestic_partner" }

      it "determines a dependent of type life partner" do
        expect(subject.extract_rel_code(enrollees2)).to eq "life partner"
      end
    end

    describe "given a life partner relationship" do
      let(:dependent_relationship_uri) { "urn:openhbx:terms:v1:individual_relationship#life_partner" }

      it "determines a dependent of type life partner" do
        expect(subject.extract_rel_code(enrollees2)).to eq "life partner"
      end
    end

  end

  describe "and the policy is a shop policy" do
    let(:employer) { double }
    let(:shop_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentShopMarket, :total_employer_responsible_amount => total_employer_responsible_amount, :composite_rating_tier_name => composite_rating_tier_name) }
    let(:total_employer_responsible_amount) { "12345.23" }
    let(:composite_rating_tier_name) { "A COMPOSITE RATING TIER NAME" }

    before :each do
      allow(subject).to receive(:find_employer).with(policy_cv).and_return(employer)
    end

    describe "with a composite rating tier" do
      it "has the composite rating tier" do
        expect(subject.extract_other_financials[:composite_rating_tier]).to eq composite_rating_tier_name
      end

      it "has the employer responsible amount" do
        expect(subject.extract_other_financials[:tot_emp_res_amt]).to eq total_employer_responsible_amount.to_f
      end
    end
  end

  describe "#responsible_person_exists?" do
    context 'of a responsible party existing' do
      let(:member) { FactoryGirl.build :member }
      let!(:person) { FactoryGirl.create(:person, members: [member])}

      before do
        responsible_party = instance_double(Openhbx::Cv2::ResponsibleParty, id: member.hbx_member_id)
        allow(policy_cv).to receive(:responsible_party).and_return(responsible_party)
      end

      it 'returns true' do
        expect(subject.responsible_person_exists?).to be_truthy
      end
    end
  end

  describe "#persist" do
    let!(:responsible_party) { ResponsibleParty.new(entity_identifier: "responsible party") }
    let!(:person) { FactoryGirl.create(:person,responsible_parties:[responsible_party])}

    context "when policy not exists and responsible party exists", dbclean: :after_each do
      let!(:plan) {FactoryGirl.create(:plan, carrier_id:'01') }
      let(:applied_aptc) { {:applied_aptc =>'0.0'} }
      let(:responsible_party_node) { instance_double(::Openhbx::Cv2::ResponsibleParty) }
      let(:created_policy) do
        Policy.create({
          plan: plan,
          eg_id: "rspec-eg-id",
          pre_amt_tot: 0.0,
          tot_res_amt: 0.0,
          kind: nil,
          cobra_eligibility_date: nil, 
          applied_aptc: 0.0,
          responsible_party_id: responsible_party.id,
          carrier_id: '01'
        })
      end

      before :each do
        allow(subject).to receive(:policy_exists?).and_return(false)
        allow(subject).to receive(:responsible_party_exists?).and_return(true)
        allow(subject).to receive(:existing_responsible_party).and_return(responsible_party)
        allow(subject).to receive(:extract_enrollment_group_id).with(policy_cv).and_return('rspec-eg-id')
        allow(subject).to receive(:extract_pre_amt_tot).and_return("0.0")
        allow(subject).to receive(:extract_tot_res_amt).and_return("0.0")
        allow(subject).to receive(:extract_other_financials).and_return(applied_aptc)
        allow(subject).to receive(:extract_rating_details).and_return({})
        allow(subject).to receive(:extract_enrollee_start).with(enrollees1).and_return(Date.today)
        allow(subject).to receive(:extract_enrollee_premium).with(enrollees1).and_return("100")
        allow(subject).to receive(:extract_enrollee_start).with(enrollees2).and_return(Date.today)
        allow(subject).to receive(:extract_enrollee_premium).with(enrollees2).and_return("100")
        allow(policy_cv).to receive(:responsible_party).and_return(responsible_party_node)
        allow(policy_cv).to receive(:previous_policy_id).and_return('')
        subject.instance_variable_set(:@plan,plan)
        allow(Policy).to receive(:create!).with({
          plan: plan,
          eg_id: "rspec-eg-id",
          pre_amt_tot: "0.0",
          tot_res_amt: "0.0",
          kind: nil,
          cobra_eligibility_date: nil, 
          applied_aptc: "0.0",
          responsible_party_id: responsible_party.id,
          carrier_id: '01'
          }).and_return(created_policy)
        allow(Observers::PolicyUpdated).to receive(:notify).with(created_policy)
      end

      it "notifies of the creation" do
        expect(Observers::PolicyUpdated).to receive(:notify).with(created_policy)
        subject.persist
      end

      it "should create policy and update responsible party for policy" do
        subject.persist
        expect(Policy.where(eg_id: "rspec-eg-id").exists?).to eq true
        expect(Policy.where(eg_id: "rspec-eg-id").first.enrollees.exists?).to eq true
        expect(Policy.where(eg_id: "rspec-eg-id").first.responsible_party_id).to eq responsible_party.id
      end
    end
  end
end

describe ExternalEvents::ExternalPolicy, "with a parsed market value param in the constructor", dbclean: :after_each  do
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment, :enrollees =>[enrollees1, enrollees2]) }
  let!(:plan) {FactoryGirl.create(:plan, carrier_id:'01') }
  let(:applied_aptc) { {:applied_aptc =>'0.0'} }
  let!(:responsible_party) { ResponsibleParty.new(entity_identifier: "responsible party") }
  let!(:person) { FactoryGirl.create(:person,responsible_parties:[responsible_party])}
  let(:responsible_party_node) { instance_double(::Openhbx::Cv2::ResponsibleParty) }
  let!(:policy_enrollment) { instance_double(Openhbx::Cv2::PolicyEnrollment) }
  let(:enrollees1) { instance_double(Openhbx::Cv2::Enrollee, subscriber?: true, member: member1)}
  let(:member1) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => subscriber_xml_id, :person_relationships => []) }
  let(:subscriber_xml_id) { "urn:whaTEVER#subscriber_id" }
  let(:dependent_xml_id) { "urn:whaTEVER#dependent_id" }
  let(:enrollees2) { instance_double(Openhbx::Cv2::Enrollee, subscriber?: false, member: member2)}
  let(:member2) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => dependent_xml_id, :person_relationships => [relationship]) }
  let(:relationship) do
    instance_double(Openhbx::Cv2::PersonRelationship,
      subject_individual: dependent_xml_id,
      object_individual: subscriber_xml_id,
      relationship_uri: dependent_relationship_uri
    )
  end
  let(:dependent_relationship_uri) { "urn:openhbx:terms:v1:individual_relationship#spouse" }

  subject { ExternalEvents::ExternalPolicy.new(policy_cv, plan, false, market_from_payload: "coverall") }

  let(:created_policy) do 
    Policy.create!(
       {
        plan: plan,
        eg_id: "rspec-eg-id",
        pre_amt_tot: "0.0",
        tot_res_amt: "0.0",
        kind: "coverall",
        cobra_eligibility_date: nil, 
        applied_aptc: "0.0",
        responsible_party_id: responsible_party.id
        }
    )
  end

    before :each do
      allow(subject).to receive(:policy_exists?).and_return(false)
      allow(subject).to receive(:responsible_party_exists?).and_return(true)
      allow(subject).to receive(:existing_responsible_party).and_return(responsible_party)
      allow(subject).to receive(:extract_enrollment_group_id).with(policy_cv).and_return('rspec-eg-id')
      allow(subject).to receive(:extract_pre_amt_tot).and_return("0.0")
      allow(subject).to receive(:extract_tot_res_amt).and_return("0.0")
      allow(subject).to receive(:extract_other_financials).and_return(applied_aptc)
      allow(subject).to receive(:extract_rating_details).and_return({})
      allow(subject).to receive(:extract_enrollee_start).with(enrollees1).and_return(Date.today)
      allow(subject).to receive(:extract_enrollee_premium).with(enrollees1).and_return("100")
      allow(subject).to receive(:extract_enrollee_start).with(enrollees2).and_return(Date.today)
      allow(subject).to receive(:extract_enrollee_premium).with(enrollees2).and_return("100")
      allow(policy_cv).to receive(:responsible_party).and_return(responsible_party_node)
      allow(policy_cv).to receive(:previous_policy_id).and_return('')
      subject.instance_variable_set(:@plan,plan)
      allow(Policy).to receive(:create!).with({
        plan: plan,
        carrier_id: "01",
        eg_id: "rspec-eg-id",
        pre_amt_tot: "0.0",
        tot_res_amt: "0.0",
        kind: "coverall",
        cobra_eligibility_date: nil, 
        applied_aptc: "0.0",
        responsible_party_id: responsible_party.id
        }).and_return(created_policy)
      allow(Observers::PolicyUpdated).to receive(:notify).with(created_policy)
    end
  
    it "notifies of creation" do
      expect(Observers::PolicyUpdated).to receive(:notify).with(created_policy)
      subject.persist
    end

    it "should populate the policy with the market being passed in the initalize method" do
      expect(subject.kind).to eq("coverall")
    end

    it "should create a new policy with the designated market kind" do
      subject.persist
      expect(Policy.where(:kind => "coverall").size).to eq(1)
    end
end

describe ExternalEvents::ExternalPolicy, "with reinstated policy cv", dbclean: :after_each  do
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment, :previous_policy_id => '1', :enrollees =>[enrollees1, enrollees2]) }
  let!(:plan) {FactoryGirl.create(:plan, carrier_id:'01') }
  let(:applied_aptc) { {:applied_aptc =>'0.0'} }

  let!(:policy_enrollment) { instance_double(Openhbx::Cv2::PolicyEnrollment) }
  let(:enrollees1) { instance_double(Openhbx::Cv2::Enrollee, subscriber?: true, member: member1)}
  let(:member1) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => subscriber_xml_id, :person_relationships => []) }
  let(:subscriber_xml_id) { "urn:whaTEVER#subscriber_id" }
  let(:dependent_xml_id) { "urn:whaTEVER#dependent_id" }
  let(:enrollees2) { instance_double(Openhbx::Cv2::Enrollee, subscriber?: false, member: member2)}
  let(:member2) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => dependent_xml_id, :person_relationships => [relationship]) }
  let(:relationship) do
    instance_double(Openhbx::Cv2::PersonRelationship,
                    subject_individual: dependent_xml_id,
                    object_individual: subscriber_xml_id,
                    relationship_uri: dependent_relationship_uri
    )
  end
  let!(:previous_policy) {FactoryGirl.create(:policy, eg_id: policy_cv.previous_policy_id, term_for_np: true, aasm_state: "terminated" )}
  let(:policy_id) {'rspec-eg-id'}
  let(:dependent_relationship_uri) { "urn:openhbx:terms:v1:individual_relationship#spouse" }
  subject { ExternalEvents::ExternalPolicy.new(policy_cv, plan, false, policy_reinstate: true) }

  let(:created_policy) do 
    Policy.create!(
       {
        plan: plan,
        eg_id: "rspec-eg-id",
        pre_amt_tot: "0.0",
        tot_res_amt: "0.0",
        kind: nil,
        cobra_eligibility_date: nil, 
        applied_aptc: "0.0",
        carrier_id: '01'
        }
    )
  end

  before :each do
    allow(subject).to receive(:policy_exists?).and_return(false)
    allow(subject).to receive(:extract_enrollment_group_id).with(policy_cv).and_return(policy_id)
    allow(subject).to receive(:extract_pre_amt_tot).and_return("0.0")
    allow(subject).to receive(:extract_tot_res_amt).and_return("0.0")
    allow(subject).to receive(:extract_other_financials).and_return(applied_aptc)
    allow(subject).to receive(:extract_rating_details).and_return({})
    allow(subject).to receive(:extract_enrollee_start).with(enrollees1).and_return(Date.today)
    allow(subject).to receive(:extract_enrollee_premium).with(enrollees1).and_return("100")
    allow(subject).to receive(:extract_enrollee_start).with(enrollees2).and_return(Date.today)
    allow(subject).to receive(:extract_enrollee_premium).with(enrollees2).and_return("100")
    allow(policy_cv).to receive(:responsible_party).and_return('')
    subject.instance_variable_set(:@plan,plan)
    allow(Policy).to receive(:create!).with({
      plan: plan,
      eg_id: "rspec-eg-id",
      pre_amt_tot: "0.0",
      tot_res_amt: "0.0",
      kind: nil,
      cobra_eligibility_date: nil, 
      applied_aptc: "0.0",
      carrier_id: '01'
      }).and_return(created_policy)
    allow(Observers::PolicyUpdated).to receive(:notify).with(created_policy)
    allow(Observers::PolicyUpdated).to receive(:notify).with(previous_policy)
  end

  it "notifies of creation" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(created_policy)
    subject.persist
  end

  it "should create a new policy for reinstated policy" do
    subject.persist
    expect(Policy.where(:eg_id => policy_id).size).to eq(1)
  end

  it "reinstated policy state should be resubmitted" do
    subject.persist
    expect(Policy.where(:eg_id => policy_id).first.aasm_state).to eq("resubmitted")
  end

  it "should set the termination non payment flag to false on previous_policy" do
    expect(previous_policy.term_for_np).to eq(true)
    expect(Observers::PolicyUpdated).to receive(:notify).with(previous_policy)
    subject.persist
    previous_policy.reload
    expect(previous_policy.term_for_np).to eq(false)
  end
end
