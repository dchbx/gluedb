require 'rails_helper'
require 'rake'
describe 'Load Seed Data for Developers', :dbclean => :around_each do
  describe 'developer:load_seed' do
    before do
      Rails.application.load_tasks
      Rake::Task["developer:load_seed"].invoke
    end

     it 'should seed data' do
      seeded_classes = [Carrier, Person, Plan, Policy, User]
      seeded_classes.each { |seeded_class| expect(seeded_class.count).to be > 0 }
    end
  end
end
