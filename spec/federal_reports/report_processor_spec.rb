require 'rails_helper'

describe ::FederalReports::ReportProcessor, :dbclean => :around_each do
  let(:plan) { FactoryGirl.create(:plan, carrier: carrier, year: 2018, coverage_type: "health", hios_plan_id: "1212") }
  let(:plan) { FactoryGirl.create(:plan, carrier: carrier, year: 2018, coverage_type: "health", hios_plan_id: "1212") }
  let(:carrier) { FactoryGirl.create(:carrier, abbrev: "GhmSi") }
  ["submitted", 'terminated', 'canceled', 'effectuated'].each do |status|
    let(:"#{status}_policy") {FactoryGirl.create(:policy, aasm_state: status, plan: plan, term_for_np: false ) }
  end
  let!(:submitted_policy) { FactoryGirl.create(:policy, id: 1, aasm_state: 'resubmitted') }
  let!(:terminated_policy) { FactoryGirl.create(:policy, id: 2, aasm_state: 'terminated') }
  let!(:canceled_policy) { FactoryGirl.create(:policy, id: 3, aasm_state: 'canceled') }
  let(:policy_report_eligibility_updated_policy_ids) {[submitted_policy.id, terminated_policy.id, canceled_policy.id]}
  let(:federal_transmission){ double(FederalTransmission, policy: canceled_policy)}
  let(:federal_transmissions){[federal_transmission]}
  let!(:void_params) {{:policy_id=> canceled_policy.id, :type=>"void", :void_cancelled_policy_ids => [canceled_policy.id], :void_active_policy_ids => [], :npt=> false}}
  let!(:termed_corrected_params) {{:policy_id=> terminated_policy.id, :type=>"corrected", :void_cancelled_policy_ids => [], :void_active_policy_ids => [terminated_policy.id], :npt=> false}}
  let!(:termed_original_params) {{:policy_id=> terminated_policy.id, :type=>"original", :void_cancelled_policy_ids =>[], :void_active_policy_ids => [terminated_policy.id], :npt=>false}}
  let!(:submitted_corrected_params) {{:policy_id=> submitted_policy.id, :type=>"corrected", :void_cancelled_policy_ids => [], :void_active_policy_ids => [submitted_policy.id], :npt=> false}}
  let!(:submitted_original_params) {{:policy_id=> submitted_policy.id, :type=>"original", :void_cancelled_policy_ids =>[], :void_active_policy_ids => [submitted_policy.id], :npt=>false}}
  let(:uploader){ ::FederalReports::ReportUploader.new }
  subject { ::FederalReports::ReportProcessor }

  before(:each) do
    submitted_policy
    terminated_policy
    canceled_policy
    allow(::FederalReports::ReportUploader).to receive(:new).and_return(uploader)
    allow(uploader).to receive(:upload).and_return(true)
    Policy.all.each do  |policy| 
      person = FactoryGirl.create(:person, authority_member_id: policy.subscriber.m_id)
      policy.subscriber.update_attributes!(m_id: person.authority_member_id)
    end
  end
  
  context "processing cancelled policies" do
    it 'calling the upload_canceled_reports_for() if the policy is cancelled but takes no action with no federal transmission' do
      canceled_policy.subscriber.update_attributes!(m_id: canceled_policy.subscriber.m_id )
      canceled_policy.reload
      subject.upload_canceled_reports_for(canceled_policy)
      expect(uploader).to_not have_received(:upload).with(void_params)
    end

    it 'calling the upload_canceled_reports_for() if the policy is cancelled ' do
      canceled_policy.federal_transmissions.create!(batch_id: "2017-02-08T14:00:00Z", report_type: "VOID", content_file: "00001",record_sequence_number:"3")
      canceled_policy.subscriber.update_attributes(coverage_start: Date.new(2018,3,16))
      canceled_policy.reload
      subject.upload_canceled_reports_for(canceled_policy)
      expect(uploader).to have_received(:upload).with(void_params)
    end
  end
    
  context "processing terminated policies" do
    it 'calling the upload_active_reports_for() returns original params if the policy has no fed tranmissions' do
      allow(uploader).to receive(:upload).with(termed_original_params).and_return(true)
      terminated_policy.subscriber.update_attributes!(coverage_start: Date.new(2018,1,1), coverage_end: Date.new(2018,12,31))
      terminated_policy.reload
      subject.upload_active_reports_for(terminated_policy)
      expect(uploader).to have_received(:upload).with(termed_original_params)
    end

    it 'calling the upload_active_reports_for() returns original params if the policy has no fed tranmissions' do
      allow(uploader).to receive(:upload).with(termed_corrected_params).and_return(true)
      terminated_policy.subscriber.update_attributes!(coverage_start: Date.new(2018,1,1), coverage_end: Date.new(2018,12,31))
      terminated_policy.federal_transmissions.create!(batch_id: "2017-02-08T14:00:00Z", report_type: "CORRECTED", content_file: "00001",record_sequence_number:"2")
      terminated_policy.reload
      subject.upload_active_reports_for(terminated_policy)
      expect(uploader).to have_received(:upload).with(termed_corrected_params)
    end
  end

  context "processing submitted policies" do
    it 'calling the upload_active_reports_for() returns original params if the policy has fed tranmissions' do
      allow(uploader).to receive(:upload).with(submitted_original_params).and_return(true)
      submitted_policy.subscriber.update_attributes!(coverage_start: Date.new(2018,1,1), coverage_end: Date.new(2018,12,31))
      submitted_policy.reload
      subject.upload_active_reports_for(submitted_policy)
      expect(uploader).to have_received(:upload).with(submitted_original_params)
    end

    it 'calling the upload_active_reports_for() returns original params if the policy has no fed tranmissions' do
      allow(uploader).to receive(:upload).with(submitted_corrected_params).and_return(true)
      submitted_policy.subscriber.update_attributes!(coverage_start: Date.new(2018,1,1), coverage_end: Date.new(2018,12,31))
      submitted_policy.reload
      submitted_policy.federal_transmissions.create!(batch_id: "2017-02-08T14:00:00Z", report_type: "CORRECTED", content_file: "00001",record_sequence_number:"1")
      submitted_policy.reload
      subject.upload_active_reports_for(submitted_policy)
      expect(uploader).to have_received(:upload).with(submitted_corrected_params)
    end
  end

  describe "finding void (cancelled & active) policy ids" do

    context 'get_void_canceled_policy_ids_of_subscriber' do
      before(:each) do
        canceled_policy.federal_transmissions.create!(batch_id: "2017-02-08T14:00:00Z", report_type: "VOID", content_file: "00001",record_sequence_number:"3")
        canceled_policy.subscriber.update_attributes!(coverage_start: Date.new(2018,3,16))
        canceled_policy.reload
      end

      context 'when aasm_state is not cancelled' do
        it 'get_void_canceled_policy_ids_of_subscriber' do
          ids = subject.get_void_canceled_policy_ids_of_subscriber(canceled_policy)
          expect(ids).to eq [canceled_policy.id]
        end
      end

      context 'when aasm_state is not cancelled' do
        it 'should return with empty ids' do
          terminated_policy.subscriber.reload
          ids = subject.get_void_canceled_policy_ids_of_subscriber(terminated_policy)
          expect(ids).to eq([])
        end
      end

      context 'when policy is not health' do
        it 'should return with empty ids' do
          canceled_policy.plan.update_attributes!(coverage_type: 'dental')
          canceled_policy.reload
          ids = subject.get_void_active_policy_ids_of_subscriber(canceled_policy)
          expect(ids).to eq([])
        end
      end
    end

    context 'get_void_active_policy_ids_of_subscriber' do
      before(:each) do
        terminated_policy.federal_transmissions.create!(batch_id: "2017-02-08T14:00:00Z", report_type: "VOID", content_file: "00001",record_sequence_number:"2")
        terminated_policy.subscriber.update_attributes!(coverage_start: Date.new(2018,1,1), coverage_end: Date.new(2018,12,31))
        terminated_policy.reload
      end

      context 'when aasm_state is not cancelled' do
        it 'get_void_canceled_policy_ids_of_subscriber' do
          ids = subject.get_void_active_policy_ids_of_subscriber(terminated_policy)
          expect(ids).to eq [terminated_policy.id]
        end
      end

      context 'when aasm_state is not terminated' do
        it 'should return with empty ids' do
          canceled_policy.subscriber.reload
          ids = subject.get_void_active_policy_ids_of_subscriber(canceled_policy)
          expect(ids).to eq([])
        end
      end

      context 'when policy is not health' do
        it 'should return with empty ids' do
          terminated_policy.plan.update_attributes!(coverage_type: 'dental')
          terminated_policy.reload
          ids = subject.get_void_active_policy_ids_of_subscriber(terminated_policy)
          expect(ids).to eq([])
        end
      end
    end
  end
end