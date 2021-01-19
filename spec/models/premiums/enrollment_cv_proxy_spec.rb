require 'rails_helper'

describe EnrollmentCvProxy do

  before(:all) do

    @xml_path = File.join(Rails.root, 'spec', 'data', 'lib', 'example_enrollment.xml')
    @xml = File.open(@xml_path)
    @enrollment_cv_proxy = EnrollmentCvProxy.new(@xml)
  end

  it 'extracts the enrollee elements' do
    @enrollment_cv_proxy.enrollees.each do |enrollee|
      expect(enrollee.class).to eq(Enrollee)
    end
  end

  it 'assigns members to enrollees' do
    @enrollment_cv_proxy.enrollees.each do |enrollee|
      #expect(enrollee.member.class).to eq(Person)
    end
  end

  it 'extracts the policy elements' do
    #expect(@enrollment_cv_proxy.policy.class).to eq(Policy)
  end

end
