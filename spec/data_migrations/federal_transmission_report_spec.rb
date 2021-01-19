require "rails_helper"
require 'nokogiri'
require File.join(Rails.root,"app","data_migrations","federal_transmission_report")

describe FederalTransmissionReport, dbclean: :after_each do
  let(:given_task_name) { "federal_transmission_report" }
  let!(:policy) { FactoryGirl.create(:policy) }
  let(:batch_const) {"Generators::Reports::Importers::FederalReportIngester::BATCH_PATH"} 
  let(:dir_file_const) {"Generators::Reports::Importers::FederalReportIngester::EOY_DIRECTORY_FILES"}
  let(:file_names_path) {"#{Rails.root}/spec/data/script/irs/irs_xmls/EOY_Request_00001_20170207T023936000Z.xml"}
  let(:original_batch_file) {"#{Rails.root}/spec/data/script/irs/irs_xmls/manifest.xml"}
  let(:corrected_batch_file) {"#{Rails.root}/spec/data/script/irs/irs_xmls/corrected_manifest.xml"}
  let(:void_batch_file) {"#{Rails.root}/spec/data/script/irs/irs_xmls/void_manifest.xml"}

  subject { FederalTransmissionReport.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'Ingest federal transmission task' do 

    before :each do
      stub_const(batch_const, original_batch_file)
      stub_const(dir_file_const, file_names_path)
    end

    it 'should ingest federal transmission info into policy' do 
      expect(policy.federal_transmissions).to eq []
      subject.migrate
      policy.reload
      expect(policy.federal_transmissions.count).to eq 1
      expect(policy.federal_transmissions.first.content_file).to eq "00001"
      expect(policy.federal_transmissions.first.record_sequence_number).to eq policy.id.to_s
      expect(policy.federal_transmissions.first.report_type).to eq "ORIGINAL"
    end

    it 'should ingest void federal transmission record info into policy' do
      stub_const(batch_const, void_batch_file)
      expect(policy.federal_transmissions).to eq []
      subject.migrate
      policy.reload
      expect(policy.federal_transmissions.first.report_type).to eq "VOID"
    end

    it 'should ingest corrected federal transmission record info into policy' do
      stub_const(batch_const, corrected_batch_file)
      expect(policy.federal_transmissions).to eq []
      subject.migrate
      policy.reload
      expect(policy.federal_transmissions.first.report_type).to eq "CORRECTED"
    end
  end
end