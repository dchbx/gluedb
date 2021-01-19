require 'rails_helper'

describe EmployerContact do

  describe "with a type of work" do
    it "should have a valid contact type" do
      subject.job_title = "manager"
      subject.valid?
      expect(subject).not_to have_at_least(1).errors_on(:job_title)
    end
  end

  describe 'contact' do
    let(:contact) { build(:employer_contact) }

    ['manager', 'director'].each do |job_title|
      context('when ' + job_title) do
        before { contact.job_title = job_title}
        it 'is valid' do
          expect(contact).to be_valid
        end
      end
    end

    ['hr', 'business'].each do |department|
      context('when ' + department) do
        before { contact.department = department}
        it 'is valid' do
          expect(contact).to be_valid
        end
      end
    end

    ['Mr.', 'Ms'].each do |name_prefix|
      context('when ' + name_prefix) do
        before { contact.name_prefix = name_prefix}
        it 'is valid' do
          expect(contact).to be_valid
        end
      end
    end

    ['Joe', 'John'].each do |first_name|
      context('when ' + first_name) do
        before { contact.first_name = first_name}
        it 'is valid' do
          expect(contact).to be_valid
        end
      end
    end

    ['Smith', 'Seinfeld'].each do |last_name|
      context('when ' + last_name) do
        before { contact.last_name = last_name}
        it 'is valid' do
          expect(contact).to be_valid
        end
      end
    end
  end
end
