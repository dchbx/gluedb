require "rails_helper"

describe ExternalEvents::ExternalPolicyMemberDrop, "given:
- an IVL policy to change
- an IVL policy cv
- a list of dropped member ids
" do
  let(:dependent_id) { "ABCDEFG" }
  let(:existing_policy_id) { "SOME POLICY ID" }
  let(:existing_policy) { instance_double(Policy, :_id => existing_policy_id, :enrollees => [], :is_shop? => false) }
  let(:dropped_member_ids) { [dependent_id] }

  let(:shop_market) { nil }
  let(:individual_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: aptc_string_value) }
  let(:policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                            individual_market: individual_market,
                                            shop_market: shop_market,
                                            premium_total_amount: premium_total_string_value,
                                            total_responsible_amount: tot_res_amt_string_value
                                           ) }
  let(:policy_cv) do
    instance_double(
      ::Openhbx::Cv2::Policy,
      :policy_enrollment => policy_enrollment,
      :enrollees => [dropped_enrollee]
    )
  end

  let(:benefit_node) { instance_double(Openhbx::Cv2::EnrolleeBenefit, :end_date => end_date) }
  let(:member_node) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => dependent_id) }
  let(:dropped_enrollee) do
    instance_double(
      Openhbx::Cv2::Enrollee,
      :member => member_node,
      :benefit => benefit_node
    )
  end

  let(:end_date) { "20150531" }

  let(:premium_total_string_value) { "456.78" }
  let(:premium_total_bigdecimal_value) { BigDecimal.new(premium_total_string_value) }
  let(:aptc_string_value) { "123.45" }
  let(:aptc_bigdecimal_value) { BigDecimal.new(aptc_string_value) }
  let(:tot_res_amt_string_value) { "333.33" }
  let(:tot_res_amt_bigdecimal_value) { BigDecimal.new(tot_res_amt_string_value) }

  subject { ExternalEvents::ExternalPolicyMemberDrop.new(existing_policy, policy_cv, dropped_member_ids) }

  it "gets the aptc from the policy_cv" do
    expect(subject.extract_aptc_amount).to eq(aptc_bigdecimal_value)
  end

  it "gets the premium_total from the policy_cv" do
    expect(subject.extract_pre_amt_tot).to eq(premium_total_bigdecimal_value)
  end

  it "gets the total responsible amount from the policy_cv" do
    expect(subject.extract_tot_res_amt).to eq(tot_res_amt_bigdecimal_value)
  end

  describe "instructed to get the totals from a different IVL policy CV" do
    let(:other_shop_market) { nil }
    let(:other_individual_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentIndividualMarket, applied_aptc_amount: other_aptc_string_value) }
    let(:other_policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                              individual_market: other_individual_market,
                                              shop_market: other_shop_market,
                                              premium_total_amount: other_premium_total_string_value,
                                              total_responsible_amount: other_tot_res_amt_string_value
                                             ) }
    let(:other_policy_cv) { instance_double(::Openhbx::Cv2::Policy, :policy_enrollment => other_policy_enrollment, :enrollees => other_enrollees) }
    let(:other_enrollees) { [other_subscriber] }
    let(:subscriber_member) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => "1") }
    let(:other_subscriber_member) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => "1") }
    let(:dependent_member) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => "2") }
    let(:subscriber) { instance_double(::Openhbx::Cv2::Enrollee, :member => subscriber_member) }
    let(:dependent) { instance_double(::Openhbx::Cv2::Enrollee, :member => dependent_member, :benefit => dependent_benefit) }
    let(:other_subscriber) { instance_double(::Openhbx::Cv2::Enrollee, :member => other_subscriber_member, :benefit => other_subscriber_benefit) }
    let(:other_subscriber_benefit) { instance_double(::Openhbx::Cv2::EnrolleeBenefit, :premium_amount => other_source_subscriber_premium_string_value) }
    let(:dependent_benefit) { instance_double(::Openhbx::Cv2::EnrolleeBenefit, :premium_amount => dependent_premium_string_value) }

    let(:other_source_subscriber_premium_string_value) { "123.37" }
    let(:other_source_subscriber_premium_bigdecimal_value) { BigDecimal.new(other_source_subscriber_premium_string_value) }
    let(:dependent_premium_string_value) { "23.37" }
    let(:dependent_premium_bigdecimal_value) { BigDecimal.new(dependent_premium_string_value) }
    let(:other_premium_total_string_value) { "756.78" }
    let(:other_premium_total_bigdecimal_value) { BigDecimal.new(other_premium_total_string_value) }
    let(:other_aptc_string_value) { "223.45" }
    let(:other_aptc_bigdecimal_value) { BigDecimal.new(other_aptc_string_value) }
    let(:other_tot_res_amt_string_value) { "533.33" }
    let(:other_tot_res_amt_bigdecimal_value) { BigDecimal.new(other_tot_res_amt_string_value) }

    before :each do
      subject.use_totals_from(other_policy_cv)
    end

    it "gets the member premium from the other policy_cv" do
      expect(subject.extract_enrollee_premium(subscriber)).to eq(other_source_subscriber_premium_bigdecimal_value)
    end

    it "falls back to the source document when it can't locate the dependent premium amount" do
      expect(subject.extract_enrollee_premium(dependent)).to eq(dependent_premium_bigdecimal_value)
    end

    it "gets the aptc from the other policy_cv" do
      expect(subject.extract_aptc_amount).to eq(other_aptc_bigdecimal_value)
    end

    it "gets the premium_total from the other policy_cv" do
      expect(subject.extract_pre_amt_tot).to eq(other_premium_total_bigdecimal_value)
    end

    it "gets the total responsible amount from the other policy_cv" do
      expect(subject.extract_tot_res_amt).to eq(other_tot_res_amt_bigdecimal_value)
    end
  end

  describe "asked to persist a termination on an IVL policy" do

    before :each do
      allow(Policy).to receive(:find).with(existing_policy_id).and_return(existing_policy)
      allow(existing_policy).to receive(:update_attributes!).with(
        :pre_amt_tot => premium_total_bigdecimal_value,
        :tot_res_amt => tot_res_amt_bigdecimal_value,
        :applied_aptc => aptc_bigdecimal_value
      ).and_return(true)
    end

    it "notifies" do
      expect(Observers::PolicyUpdated).to receive(:notify).with(existing_policy)
      subject.persist
    end
  end

  describe "asked to persist a termination on an IVL policy with a 12/31 end date" do

    let(:end_date) { "20151231" }

    before :each do
      allow(Policy).to receive(:find).with(existing_policy_id).and_return(existing_policy)
      allow(existing_policy).to receive(:update_attributes!).with(
        :pre_amt_tot => premium_total_bigdecimal_value,
        :tot_res_amt => tot_res_amt_bigdecimal_value,
        :applied_aptc => aptc_bigdecimal_value
      ).and_return(true)
    end

    it "doesn't notify" do
      expect(Observers::PolicyUpdated).not_to receive(:notify).with(existing_policy)
      subject.persist
    end
  end
end

describe ExternalEvents::ExternalPolicyMemberDrop, "given:
- a SHOP policy to change
- a SHOP policy cv
- a list of dropped member ids
" do
  let(:existing_policy_id) { "SOME POLICY ID" }
  let(:existing_policy) { instance_double(Policy, :_id => existing_policy_id) }
  let(:dropped_member_ids) { [] }

  let(:individual_market) { nil }
  let(:shop_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentShopMarket,total_employer_responsible_amount: emp_res_amt_string_value) }
  let(:policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                            individual_market: individual_market,
                                            shop_market: shop_market,
                                            premium_total_amount: premium_total_string_value,
                                            total_responsible_amount: tot_res_amt_string_value
                                           ) }
  let(:policy_cv) { instance_double(::Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment) }

  let(:premium_total_string_value) { "456.78" }
  let(:premium_total_bigdecimal_value) { BigDecimal.new(premium_total_string_value) }
  let(:emp_res_amt_string_value) { "123.45" }
  let(:emp_res_amt_bigdecimal_value) { BigDecimal.new(emp_res_amt_string_value) }
  let(:tot_res_amt_string_value) { "333.33" }
  let(:tot_res_amt_bigdecimal_value) { BigDecimal.new(tot_res_amt_string_value) }

  subject { ExternalEvents::ExternalPolicyMemberDrop.new(existing_policy, policy_cv, dropped_member_ids) }

  it "gets the employer contribution from the policy_cv" do
    expect(subject.extract_employer_contribution).to eq(emp_res_amt_bigdecimal_value)
  end

  it "gets the premium_total from the policy_cv" do
    expect(subject.extract_pre_amt_tot).to eq(premium_total_bigdecimal_value)
  end

  it "gets the total responsible amount from the policy_cv" do
    expect(subject.extract_tot_res_amt).to eq(tot_res_amt_bigdecimal_value)
  end

  describe "instructed to get the totals from a different SHOP policy CV" do
    let(:other_individual_market) { nil }
    let(:other_shop_market) { instance_double(::Openhbx::Cv2::PolicyEnrollmentShopMarket,total_employer_responsible_amount: other_emp_res_amt_string_value) }
    let(:other_policy_enrollment) { instance_double(::Openhbx::Cv2::PolicyEnrollment,
                                                    individual_market: other_individual_market,
                                                    shop_market: other_shop_market,
                                                    premium_total_amount: other_premium_total_string_value,
                                                    total_responsible_amount: other_tot_res_amt_string_value
                                                   ) }
    let(:other_policy_cv) { instance_double(::Openhbx::Cv2::Policy, :policy_enrollment => other_policy_enrollment) }

    let(:other_premium_total_string_value) { "456.78" }
    let(:other_premium_total_bigdecimal_value) { BigDecimal.new(other_premium_total_string_value) }
    let(:other_emp_res_amt_string_value) { "123.45" }
    let(:other_emp_res_amt_bigdecimal_value) { BigDecimal.new(other_emp_res_amt_string_value) }
    let(:other_tot_res_amt_string_value) { "333.33" }
    let(:other_tot_res_amt_bigdecimal_value) { BigDecimal.new(other_tot_res_amt_string_value) }

    before :each do
      subject.use_totals_from(other_policy_cv)
    end

    it "gets the employer contribution from the other policy_cv" do
      expect(subject.extract_employer_contribution).to eq(other_emp_res_amt_bigdecimal_value)
    end

    it "gets the premium_total from the other_policy_cv" do
      expect(subject.extract_pre_amt_tot).to eq(other_premium_total_bigdecimal_value)
    end

    it "gets the total responsible amount from the other_policy_cv" do
      expect(subject.extract_tot_res_amt).to eq(other_tot_res_amt_bigdecimal_value)
    end

  end
end
