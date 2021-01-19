namespace :developer do
  desc "Load Demo People"
  task :load_people => :environment do
    Person.create!(name_first: "Tony", name_last: "Stark")
    person = Person.where(name_first: "Tony").first
    member = person.members.build
    member.gender = "male"
    member.save!
    puts("Person #{person.name_first} now has #{person.members.count} member.")  unless Rails.env.test?
    Person.create!(name_first: "Pepper", name_last: "Potts")
    person = Person.where(name_first: "Pepper").first
    member = person.members.build
    member.gender = "female"
    member.save!
    puts("Person #{person.name_first} now has #{person.members.count} member.") unless Rails.env.test?
  end
end
