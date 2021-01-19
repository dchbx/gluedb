module ChangeSets
  class IndividualChangeSet
    attr_reader :resource, :record

    def initialize(remote_resource)
      @resource = remote_resource
      @individual_exists = remote_resource.exists?
      if @individual_exists
        @record = remote_resource.record
      end
      @home_address_changer = ::ChangeSets::PersonAddressChangeSet.new("home")
      @mailing_address_changer = ::ChangeSets::PersonAddressChangeSet.new("mailing")
      @home_email_changer = ::ChangeSets::PersonEmailChangeSet.new("home")
      @work_email_changer = ::ChangeSets::PersonEmailChangeSet.new("work")
      @home_phone_changer = ::ChangeSets::PersonPhoneChangeSet.new("home")
      @work_phone_changer = ::ChangeSets::PersonPhoneChangeSet.new("work")
      @mobile_phone_changer = ::ChangeSets::PersonPhoneChangeSet.new("mobile")
      @dob_changer = ::ChangeSets::PersonDobChangeSet.new
      @relationship_changer = ::ChangeSets::MemberRelationshipChangeSet.new
    end

    def member
      @member ||= record.members.detect { |m| m.hbx_member_id == resource.hbx_member_id }
    end

    def individual_exists?
      @individual_exists
    end

    def create_individual_resource
      new_person = build_new_person
      @record = new_person
      new_person.save
    end

    def full_error_messages
      record.errors.full_messages
    end

    def member_active_policies
      all_policies = member.policies
      non_canceled_policies = all_policies.reject(&:canceled?)
      non_canceled_policies.select do |pol|
        pol.currently_active_for?(member.hbx_member_id) ||
          pol.future_active_for?(member.hbx_member_id)
      end
    end

    def notify_report_eligible_policies
      all_policies = member.policies
      all_policies.reject(&:canceled?).each do |pol|
        Observers::PolicyUpdated.notify(pol)
      end
    end

    def now_or_future_active_policies
      @now_or_future_active_polices ||= member_active_policies
    end

    def transmission_policies
      @transmission_policies ||= determine_policies_to_transmit
    end

    def process_first_edi_change
      if home_address_changed?
        @home_address_changer.perform_update(record, resource, determine_policies_to_transmit)
      elsif mailing_address_changed?
        @mailing_address_changer.perform_update(record, resource, determine_policies_to_transmit)
      elsif names_changed?
        process_name_change
      elsif ssn_changed?
        process_ssn_change
      elsif gender_changed?
        process_gender_change
      elsif work_email_changed?
        @work_email_changer.perform_update(record, resource, determine_policies_to_transmit, !multiple_contact_changes?)
      elsif work_phone_changed?
        @work_phone_changer.perform_update(record, resource, determine_policies_to_transmit, !multiple_contact_changes?)
      elsif mobile_phone_changed?
        @mobile_phone_changer.perform_update(record, resource, determine_policies_to_transmit, !multiple_contact_changes?)
      elsif home_phone_changed?
        @home_phone_changer.perform_update(record, resource, determine_policies_to_transmit, !multiple_contact_changes?)
      elsif home_email_changed?
        @home_email_changer.perform_update(record, resource, determine_policies_to_transmit, !multiple_contact_changes?)
      elsif dob_changed?
        notify_report_eligible_policies
        @dob_changer.perform_update(member, resource, now_or_future_active_policies)
      elsif relationships_changed?
        process_relationship_change
      end
    end

    def relationships_changed?
      return false unless individual_exists?
      return false if now_or_future_active_policies.empty?
      @relationship_changer.applicable?(member, resource, now_or_future_active_policies)
    end

    def process_relationship_change
      @relationship_changer.perform_update(member, resource, now_or_future_active_policies)
    end

    def process_name_change
      cs = ::ChangeSets::PersonNameChangeSet.new
      cs.perform_update(record, resource, determine_policies_to_transmit)
    end

    def process_ssn_change
      notify_report_eligible_policies
      cs = ::ChangeSets::PersonSsnChangeSet.new
      cs.perform_update(member, resource, determine_policies_to_transmit)
    end

    def process_gender_change
      cs = ::ChangeSets::PersonGenderChangeSet.new
      cs.perform_update(member, resource, determine_policies_to_transmit)
    end

    def any_changes?
      change_count > 0
    end

    def multiple_changes?
      change_count > 1
    end

    def change_count
      @change_count ||= (change_collection.count { |a| a })
    end

    def change_collection
      [
        home_address_changed?,
        mailing_address_changed?,
        names_changed?,
        ssn_changed?,
        gender_changed?,
        home_email_changed?,
        work_email_changed?,
        home_phone_changed?,
        work_phone_changed?,
        mobile_phone_changed?,
        dob_changed?,
        relationships_changed?
      ]
    end

    def multiple_contact_changes?
      (contact_change_collection.count { |a| a }) > 1
    end

    def contact_change_collection
      [
        home_email_changed?,
        work_email_changed?,
        home_phone_changed?,
        work_phone_changed?,
        mobile_phone_changed?
      ]
    end

    def dob_changed?
      resource.dob != member.dob
    end

    def home_phone_changed?
      @home_phone_changer.applicable?(record, resource)
    end

    def work_phone_changed?
      @work_phone_changer.applicable?(record, resource)
    end

    def mobile_phone_changed?
      @mobile_phone_changer.applicable?(record, resource)
    end

    def home_email_changed?
      @home_email_changer.applicable?(record, resource)
    end

    def work_email_changed?
      @work_email_changer.applicable?(record, resource)
    end

    def home_address_changed?
      @home_address_changer.applicable?(record, resource)
    end

    def mailing_address_changed?
      @mailing_address_changer.applicable?(record, resource)
    end

    def names_changed?
      name_values_changed?(record.name_first, resource.name_first) ||
        name_values_changed?(record.name_last, resource.name_last) ||
        name_values_changed?(record.name_middle, resource.name_middle) ||
        name_values_changed?(record.name_sfx, resource.name_sfx) ||
        name_values_changed?(record.name_pfx, resource.name_pfx)
    end

    def name_values_changed?(record_value, resource_value)
      return false if (record_value.blank? && resource_value.blank?)
      return true if record_value.blank?
      return true if resource_value.blank?
      !(record_value.strip.downcase == resource_value.strip.downcase)
    end

    def ssn_changed?
      return false if (resource.ssn.blank? && member.ssn.blank?)
      resource.ssn != member.ssn
    end

    def gender_changed?
      resource.gender != member.gender
    end

    def dropping_subscriber_home_address?
      return false unless individual_exists?
      policies_to_transmit = determine_policies_to_transmit
      return false if policies_to_transmit.blank?
      home_address = @resource.addresses.detect { |au| au.address_type == "home" }
      return false if home_address
      policies_to_transmit.any? do |pol|
        sub = pol.subscriber
        sub.m_id == member.hbx_member_id
      end
    end

    protected

    def determine_policies_to_transmit
      selected_policies = now_or_future_active_policies.inject({}) do |acc, pol|
        carrier_id = pol.plan.carrier_id
        individual_market = pol.employer_id.blank?
        lookup_key = [carrier_id, individual_market]
        if acc.has_key?(lookup_key)
          if acc[lookup_key].policy_start <= pol.policy_start
            acc[lookup_key] = pol
          end
        else
          acc[lookup_key] = pol
        end
        acc
      end
      selected_policies.values
    end

    def build_new_person
      person_properties = resource.to_hash
      person_properties[:members] = [Member.new(resource.member_hash)]
      person_properties[:addresses] = resource.addresses.map { |addy| Address.new(addy.to_hash) }
      person_properties[:emails] = resource.emails.map { |addy| Email.new(addy.to_hash) }
      person_properties[:phones] = resource.phones.map { |addy| Phone.new(addy.to_hash) }
      Person.new(person_properties)
    end
  end
end
