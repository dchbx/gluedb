require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "mass_merge_people_from_csv.rb")

describe MassMergePeopleFromCSV, dbclean: :after_each do
  let(:given_task_name) { "extract_mongo_ids_from_hbx_ids" }
  let(:authority_member_hbx_ids) { ["111111", "333333"] }
  let!(:authority_members) do
  	authority_member_hbx_ids.each do |member_id|
      FactoryGirl.create(:person, authority_member_id: member_id)
    end
  end
  let(:test_authority_member_mongo_id) { Person.where(authority_member_id: "111111").first.id }
  let(:non_authority_member_hbx_ids) { ["222222", "444444"] }
  let!(:non_authority_members) do
  	non_authority_member_hbx_ids.each do |member_id|
      FactoryGirl.create(:person, authority_member_id: member_id)
    end
  end
  let(:test_non_authority_member_mongo_id) { Person.where(authority_member_id: "222222").first.id }
  # From the CSV
  let(:authority_member_ids_source_csv_location) {	Rails.root.to_s + "/spec/data_migrations/test_members_to_merge.csv" }

  describe "given a task name" do 
  	subject { MassMergePeopleFromCSV.new(given_task_name, double(:current_scope => nil)) }

    it "has the given task name" do 
      expect(subject.name).to eql given_task_name
    end
  end

  describe "#migrate" do
    before(:each) do
      ENV['csv_filename'] = authority_member_ids_source_csv_location
    end

    subject { MassMergePeopleFromCSV.new(given_task_name, double(:current_scope => nil)) }

    it "runs the generated rake tasks as system commands" do
      subject.migrate
      # Confirms that rake task ran successfully
      non_authority_member_hbx_ids.each do |person_to_remove_hbx_id|
        person_to_remove = Person.where(authority_member_id: person_to_remove_hbx_id).first
        expect(person_to_remove).to eq(nil)
      end
    end
  end
end

