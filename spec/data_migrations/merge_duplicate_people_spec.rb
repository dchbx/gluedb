require "rails_helper"
require File.join(Rails.root,"app","data_migrations","merge_duplicate_people")

describe MergeDuplicatePeople, dbclean: :after_each do
  let(:given_task_name) { "merge_duplicate_people" }
  let(:person_to_keep) { FactoryGirl.create(:person) }
  let(:person_to_remove) { FactoryGirl.create(:person) }
  subject { MergeDuplicatePeople.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do 
    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'merge the people' do 

    before(:each) do 
      allow(ENV).to receive(:[]).with("person_to_keep").and_return(person_to_keep._id)
      allow(ENV).to receive(:[]).with("persons_to_remove").and_return(person_to_remove._id)
    end

    it 'should merge any non-duplicate addresses' do
      addresses = (person_to_keep.addresses.map(&:full_address) + person_to_remove.addresses.map(&:full_address)).uniq.sort
      subject.merge_addresses(ENV['person_to_keep'],person_to_remove)
      person_to_keep.reload
      new_addresses = person_to_keep.addresses.map(&:full_address).uniq
      expect(new_addresses).to eq addresses
    end

    it 'should merge any non-duplicate phones' do
      phones = (person_to_keep.phones.map(&:phone_number) + person_to_remove.phones.map(&:phone_number)).uniq.sort
      subject.merge_phones(ENV['person_to_keep'],person_to_remove)
      person_to_keep.reload
      new_phones = person_to_keep.phones.map(&:phone_number).uniq.sort
      expect(new_phones).to eq phones
    end

    it 'should merge any non-duplicate emails' do
      emails = (person_to_keep.emails.map(&:email_address) + person_to_remove.emails.map(&:email_address)).uniq.sort
      subject.merge_emails(ENV['person_to_keep'],person_to_remove)
      person_to_keep.reload
      new_emails = person_to_keep.emails.map(&:email_address).uniq.sort
      expect(new_emails).to eq emails
    end

    it 'should move all the members from the duplicate person' do
      total_members_before = person_to_keep.members.size + person_to_remove.members.size
      member_ids_before = (person_to_keep.members.map(&:hbx_member_id) + person_to_remove.members.map(&:hbx_member_id)).uniq.sort
      subject.move_and_delete_members(ENV['person_to_keep'],person_to_remove)
      person_to_keep.reload
      person_to_remove.reload
      expect(person_to_keep.members.size).to eq total_members_before
      expect(person_to_remove.members.size).to eq 0
      expect(person_to_keep.members.map(&:hbx_member_id)).to eq member_ids_before
      expect(person_to_remove.members.map(&:hbx_member_id)).to eq []
    end

    it 'should unset the authority member id from the duplicate person' do
      subject.unset_authority_member_id(person_to_remove)
      person_to_remove.reload
      expect(person_to_remove.authority_member_id).to eq nil 
    end
  end
end
