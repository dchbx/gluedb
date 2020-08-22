load Rails.root.to_s + '/lib/tasks/merge_duplicate_people.rake'
require File.join(Rails.root, "lib/mongoid_migration_task")

class MassMergePeopleFromCSV < MongoidMigrationTask
  def migrate
    csv_file = ENV['csv_filename']
    if csv_file.present?
      mongo_ids_hash = process_mongo_ids_from_csv(csv_file)
      invoke_merge_duplicate_people_rakes(mongo_ids_hash)
    else
      puts("No CSV file present.") unless Rails.env.test?
    end
  end
  
  # Each row should have a authority member ID column which is for the
  # person to keep, with the person to merge id next to it
  def process_mongo_ids_from_csv(csv_file)
  	# Get rid of headers
  	mongo_ids_hash = {}
  	CSV.read(csv_file).each do |row|
  	  # Skips the header Row
  	  next if CSV.read(csv_file)[0] == row
  	  # Removes nil values (blank cells) from row array
  	  row = row.compact
  	  # Skips entirely blank rows
  	  next if row.length == 0
      # Authority HBX id row[0]
      # Non Authority member ID should be row[1]
      # row[1] will be merged into the authority member id
      authority_member_id = row[0]
      person_to_keep_mongo_id =  Person.where(authority_member_id: authority_member_id).first.id
      non_authority_member_id = row[1]
      person_to_merge_mongo_id = Person.where(authority_member_id: non_authority_member_id).first.id
      # Hash is structured as follows
      # There may be multiple people to merge, so consolidate in a hash
      # {
      #  authority_member_id: [
      #    person_to_keep_mongo_id,
      #    [person_to_merge_mongo_id, person_to_merge_mongo_id]
      #   ]
      # }
      if mongo_ids_hash.key?(authority_member_id)
        if person_to_merge_mongo_id.present?
          mongo_ids_hash[authority_member_id][1] << person_to_merge_mongo_id
        end
      # Should start here since hash will be blank
      else
        if person_to_keep_mongo_id.present? && person_to_merge_mongo_id.present?
          mongo_ids_hash[authority_member_id] = [person_to_keep_mongo_id, [person_to_merge_mongo_id]]
        end
      end
    end
    mongo_ids_hash
  end

  def invoke_merge_duplicate_people_rakes(mongo_ids_hash)
  	commands_list = []
  	# Mongo ids value is a multi dimensional array with the structure of
  	# [person_to_keep_mongo_id, [person_to_merge_mongo_id, person_to_merge_mongo_id]]
  	mongo_ids_hash.each do |authority_member_id, mongo_ids|
  	  person_to_keep_id = mongo_ids[0]
  	  # Note: This main contain multiple ids, its an array
  	  people_to_remove_ids = mongo_ids[1]
  	  if people_to_remove_ids.length > 1
        people_to_remove_ids = people_to_remove_ids.join(",")
  	  else
        people_to_remove_ids = people_to_remove_ids.join(",")
  	  end
      # Executes rake task, sets ENV variables as arguements
      ENV['person_to_keep'] = person_to_keep_id
      ENV['persons_to_remove'] = people_to_remove_ids
      Rake::Task['migrations:merge_duplicate_people'].execute
    end
  end
end
