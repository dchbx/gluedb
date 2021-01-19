# Merges duplicate people
require File.join(Rails.root, "lib/mongoid_migration_task")

class MergeDuplicatePeople < MongoidMigrationTask

  def merge_addresses(keep_id,remove_id)
    person_to_keep = Person.find(keep_id)
    person_to_remove = Person.find(remove_id)
    person_to_remove.addresses.each do |address|
      person_to_keep.merge_address(address)
    end
  end

  def merge_phones(keep_id,remove_id)
    person_to_keep = Person.find(keep_id)
    person_to_remove = Person.find(remove_id)
    person_to_remove.phones.each do |phone|
      person_to_keep.merge_phone(phone)
    end
  end

  def merge_emails(keep_id,remove_id)
    person_to_keep = Person.find(keep_id)
    person_to_remove = Person.find(remove_id)
    person_to_remove.emails.each do |email|
      person_to_keep.merge_email(email)
    end
    unless Rails.env.test?
      if person_to_remove.authority_member_id.blank?
        puts("Successfully merged #{person_to_remove.id.to_s} into #{person_to_keep.id.to_s}.")
      else
        puts("Unable to remove authority member ID.")
      end
    end
  end

  def move_and_delete_members(keep_id,remove_id)
    person_to_keep = Person.find(keep_id)
    person_to_remove = Person.find(remove_id)
    move_members(person_to_keep,person_to_remove)
    person_to_keep.save
    remove_members(person_to_remove)
    person_to_remove.save
  end

  def move_members(person_to_keep,person_to_remove)
    person_to_remove.members.each do |member|
      person_to_keep.members << member.dup
    end
    person_to_keep.save
    return person_to_keep
  end

  def remove_members(person_to_remove)
    person_to_remove.unset(:authority_member_id)
    person_to_remove.save
    person_to_remove.members.destroy_all
  end

  def unset_authority_member_id(remove_id)
    person_to_remove = Person.find(remove_id)
    person_to_remove.unset(:authority_member_id)
  end

  def migrate
    ENV['people_to_remove'].split(",").each do |person_to_remove|
      move_and_delete_members(ENV['person_to_keep'],person_to_remove)
      unset_authority_member_id(person_to_remove)
      merge_addresses(ENV['person_to_keep'],person_to_remove)
      merge_phones(ENV['person_to_keep'],person_to_remove)
      merge_emails(ENV['person_to_keep'],person_to_remove)
    end
  end
end