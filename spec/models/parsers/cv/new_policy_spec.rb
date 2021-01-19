require 'rails_helper'

describe Parsers::Cv::NewPolicy do

  before :all do
    NAMESPACES = { ns1: 'http://openhbx.org/api/terms/1.0'}

    @xml_path = File.join(Rails.root, 'spec', 'data', 'lib', 'example_enrollment.xml')
    @xml = File.open(@xml_path)
    @xml_doc = Nokogiri::XML(@xml)
    @xml_doc = @xml_doc.xpath('//ns1:policy', NAMESPACES).first
    @policy_parser = Parsers::Cv::NewPolicy.new(@xml_doc)
  end

  it 'should read total employee responsible amount' do
    expect(@policy_parser.plan_year).to eq("2014")
  end

  it 'should read plan year' do
    expect(@policy_parser.tot_emp_res_amt).to eq("11.1")
  end

  it 'should read employer id' do
    expect(@policy_parser.employer_id).to eq('53e6731deb899a460302a120')
  end

  it 'should read the broker npn' do
    expect(@policy_parser.broker_npn).to eq('broker npn for testing')
    expect(@policy_parser.to_hash[:broker_npn]).to eq('broker npn for testing')
  end
end
