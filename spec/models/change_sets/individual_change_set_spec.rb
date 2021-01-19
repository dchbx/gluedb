require 'rails_helper'

describe ::ChangeSets::IndividualChangeSet do
  let(:remote_resource) { instance_double("::RemoteResources::Individual", :exists? => remote_resource_exists, :record => existing_record) }

  let(:changeset) { ::ChangeSets::IndividualChangeSet.new(remote_resource) }
  context "with a record that already exists" do

    describe "#notify_report_eligible_policies" do
      let(:member_id) { "SOME MEMBER ID" }
      let(:remote_resource_exists) { true }
      let(:changed_policy) { instance_double(Policy, canceled?: false) }
      let(:existing_record) do
        Person.new(:members => [member])
      end
      let(:member) do
        Member.new(:hbx_member_id => member_id)
      end
      let(:member_policies) { [changed_policy] }

      before :each do
        allow(remote_resource).to receive(:hbx_member_id).and_return(member_id)
        allow(member).to receive(:policies).and_return(member_policies)
      end
 
      it "notifies the affected policies" do
        expect(Observers::PolicyUpdated).to receive(:notify).with(changed_policy)
        changeset.notify_report_eligible_policies
      end
    end

    describe "#individual_exists?" do
      let(:remote_resource_exists) { false }
      let(:existing_record) { nil }
      subject { changeset.individual_exists? }
      it { is_expected.to be_falsey }
    end

    describe "#create_individual_resource" do
      let(:created_person) { double(:save => create_person_result) }
      let(:remote_resource_exists) { false }
      let(:existing_record) { nil }
      let(:member_hash) do
        {}
      end

      let(:person_parameters) do
        { 
          :members => [created_member],
          :addresses => [],
          :phones => [],
          :emails => []
        }
      end

      let(:created_member) { double }

      before :each do
        allow(remote_resource).to receive(:to_hash).and_return(person_parameters)
        allow(remote_resource).to receive(:member_hash).and_return(member_hash)
        allow(remote_resource).to receive(:addresses).and_return([])
        allow(remote_resource).to receive(:phones).and_return([])
        allow(remote_resource).to receive(:emails).and_return([])
        allow(Member).to receive(:new).with(member_hash).and_return(created_member)
        allow(Person).to receive(:new).with(hash_including(person_parameters)).and_return(created_person)
      end

      subject { changeset.create_individual_resource }
      context "with valid data" do
        let(:create_person_result) { true }

        it { is_expected.to eq(create_person_result) }

        it "initializes the person, using attributes from the remote resource" do
          expect(Person).to receive(:new).with(person_parameters)
          subject
        end

        it "saves the new person" do
          expect(created_person).to receive(:save)
          subject
        end
      end

      context "with invalid data" do
        let(:error_messages) { double }
        let(:create_person_result) { false }
        let(:record_error_proxy) { double(:full_messages => error_messages) }

        before :each do
          allow(created_person).to receive(:errors).and_return(record_error_proxy)
        end

        it { is_expected.to eq(create_person_result) }
        it "initializes the person, using attributes from the remote resource" do
          expect(Person).to receive(:new).with(person_parameters)
          subject
        end
        it "attempts to save the new person" do
          expect(created_person).to receive(:save)
          subject
        end
        it "populates the validation errors" do
          subject
          expect(changeset.full_error_messages).to eq(error_messages)
        end
      end
    end
  end

  context "with a record that does exist" do
    let(:remote_resource_exists) { true }
    let(:remote_resource) { double(:exists? => remote_resource_exists, :record => existing_record, :name_first => nil, :name_middle => nil, :name_last => nil, :name_pfx => nil, :name_sfx => nil, :ssn => nil, :gender => nil, :dob => nil, :hbx_member_id => member_id) }
    let(:existing_record) do
      Person.new(:members => [Member.new(:hbx_member_id => member_id)])
    end
    let(:member_id) { "some member id whatever" }
    let(:home_address_changer) { double }
    let(:mailing_address_changer) { double }
    let(:home_phone_changer) { double }
    let(:work_phone_changer) { double }
    let(:mobile_phone_changer) { double }
    let(:home_email_changer) { double }
    let(:work_email_changer) { double }
    let(:home_address_changed) { false }
    let(:mailing_address_changed) { false }
    let(:home_email_changed) { false }
    let(:work_email_changed) { false }
    let(:home_phone_changed) { false }
    let(:work_phone_changed) { false }
    let(:mobile_phone_changed) { false }

    before :each do 
      allow(::ChangeSets::PersonAddressChangeSet).to receive(:new).with("home").and_return(home_address_changer)
      allow(::ChangeSets::PersonAddressChangeSet).to receive(:new).with("mailing").and_return(mailing_address_changer)
      allow(::ChangeSets::PersonPhoneChangeSet).to receive(:new).with("home").and_return(home_phone_changer)
      allow(::ChangeSets::PersonPhoneChangeSet).to receive(:new).with("work").and_return(work_phone_changer)
      allow(::ChangeSets::PersonPhoneChangeSet).to receive(:new).with("mobile").and_return(mobile_phone_changer)
      allow(::ChangeSets::PersonEmailChangeSet).to receive(:new).with("home").and_return(home_email_changer)
      allow(::ChangeSets::PersonEmailChangeSet).to receive(:new).with("work").and_return(work_email_changer)
      allow(home_address_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(home_address_changed)
      allow(mailing_address_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(mailing_address_changed)
      allow(home_phone_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(home_phone_changed)
      allow(work_phone_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(work_phone_changed)
      allow(mobile_phone_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(mobile_phone_changed)
      allow(home_email_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(home_email_changed)
      allow(work_email_changer).to receive(:applicable?).with(existing_record, remote_resource).and_return(work_email_changed)
    end

    describe "dropping the home address" do
      before :each do
        allow(remote_resource).to receive(:addresses).and_return([mailing_address, work_address])
      end

      let(:mailing_address) {
        instance_double("::RemoteResources::Address", :address_type => "mailing")
      }
      let(:work_address) {
        instance_double("::RemoteResources::Address", :address_type => "work")
      }

      describe "with existing policies" do
        before(:each) do
          allow(changeset).to receive(:determine_policies_to_transmit).and_return([policy])
        end
        
        let(:policy) { double(:subscriber => subscriber) }
        let(:subscriber) { double(:m_id => subscriber_member_id_value) }

        describe "where the member is a subscriber" do
          let(:subscriber_member_id_value) { member_id }
          describe "#dropping_subscriber_home_address?" do
            subject { changeset.dropping_subscriber_home_address? }
            it { is_expected.to be_truthy }
          end
        end

        describe "where the member is NOT a subscriber" do
          let(:subscriber_member_id_value) { "somebody elses id" }
          describe "#dropping_subscriber_home_address?" do
            subject { changeset.dropping_subscriber_home_address? }
            it { is_expected.to be_falsey}
          end
        end
      end

    end

    describe "#individual_exists?" do
      subject { changeset.individual_exists? }
      it { is_expected.to be_truthy }
    end

    context "with a no changes" do
      describe "#any_changes?" do
        subject { changeset.any_changes? }
        it { is_expected.to be_falsey }
      end

      describe "#multiple_changes?" do
        subject { changeset.multiple_changes? }
        it { is_expected.to be_falsey }
      end
    end

    context "with a change of home address" do
      let(:home_address_changed) { true }

      describe "#any_changes?" do
        subject { changeset.any_changes? }
        it { is_expected.to be_truthy }
      end

      describe "#multiple_changes?" do
        subject { changeset.multiple_changes? }
        it { is_expected.to be_falsey }
      end
    end

    context "with a change of dob change" do
      let(:dob_changed) { true }

      before(:each) do
        allow(existing_record.members.first).to receive(:dob).and_return(Date.today)
      end

      describe "#any_changes?" do
        subject { changeset.any_changes? }
        it { is_expected.to be_truthy }
      end

      describe "#multiple_changes?" do
        subject { changeset.multiple_changes? }
        it { is_expected.to be_falsey }
      end
    end

    context "with a change of home address, and a change of work email" do
      let(:home_address_changed) { true }
      let(:work_email_changed) { true }

      describe "#any_changes?" do
        subject { changeset.any_changes? }
        it { is_expected.to be_truthy }
      end

      describe "#multiple_changes?" do
        subject { changeset.multiple_changes? }
        it { is_expected.to be_truthy }
      end
    end
  end
end
