require 'rails_helper'

describe ::FederalReports::ReportUploader, :dbclean => :after_each do

  let(:canceled_policy){double(:id =>  "1")}
  let(:params) {{:policy_id=> canceled_policy.id, :type=>"void", :void_cancelled_policy_ids => [canceled_policy.id], :void_active_policy_ids => [], :npt=> false}}
  let(:pdf_file) {"file.pdf"}
  let(:xml_file) {"file.zip"}
  let(:policy) {double}
  let(:exception) {FederalReports::ReportUploadError.new(canceled_policy.id, "failed to remove tax docs")}

  subject { ::FederalReports::ReportUploader.new }
  
  context "uploading policies" do

  before(:each) do
    subject.instance_variable_set(:@pdf_file, pdf_file)
    subject.instance_variable_set(:@xml_file, xml_file)
    Policy.all.each{ |policy| FactoryGirl.create(:person, authority_member_id: policy.subscriber.m_id)}
    allow(subject).to receive(:generate_1095A_pdf).with(params).and_return(pdf_file)
    allow(subject).to receive(:generate_h41_xml).with(params).and_return(xml_file)
    allow(subject).to receive(:upload_1095).with(pdf_file, 'tax-documents').and_return(true)
    allow(subject).to receive(:upload_h41).with(pdf_file, "internal-artifact-transport").and_return(true)
    allow(subject).to receive(:upload_1095).with(pdf_file, 'tax-documents').and_return(true)
    allow(subject).to receive(:upload_h41).with(xml_file, "internal-artifact-transport").and_return(true)
    allow(subject).to receive(:persist_new_doc).and_return(true)
    allow(Policy).to receive(:find).and_return(policy)
  end

    it 'sftp and s3 methods are hit' do 
      allow(subject).to receive(:remove_tax_docs).and_return(true)
      subject.upload(params)
      expect(subject).to have_received(:generate_1095A_pdf).with(params) 
      expect(subject).to have_received(:upload_1095).with(pdf_file, 'tax-documents')
      expect(subject).to have_received(:upload_h41).with(xml_file, "internal-artifact-transport")
    end

    it 'removes tax docs after generating them' do 
      File.open("file.pdf", "w"){|f|f.puts "test"}
      File.open("file.zip", "w"){|f|f.puts "test"}
      subject.upload(params)
      expect(File).not_to exist(pdf_file) 
      expect(File).not_to exist(xml_file) 
    end

    it 'returns a ReportUploadError if something goes wrong'do
      allow(subject).to receive(:remove_tax_docs).and_raise(exception)
      expect { subject.upload(params) }.to raise_error(FederalReports::ReportUploadError)
    end
    
  end
end
