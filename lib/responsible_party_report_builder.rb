require 'spreadsheet'
require 'csv'

class ResponsiblePartyReportBuilder

  attr_reader :calender_year

  def initialize(calender_year = Date.today.year)
  	@calender_year = calender_year
  end

  def generate
  	workbook = Spreadsheet::Workbook.new
    sheet = workbook.create_worksheet :name => 'Responsible Party Data'
    index = 0
    current = 0

    columns = ['Policy Id', 'Enrollment Group Id', 'Responsible Party', 'Responsible Party SSN', 'Responsible Party DOB', 'Responsible Party Address']
    sheet.row(index).concat columns

    policies_by_subscriber.each do |row, policies|
      policies.each do |policy|
        begin
          current += 1
          puts "at #{current}" if current % 1000 == 0

          next unless policy.responsible_party_id.present?
          next if policy.kind == 'coverall'
          next unless valid_policy?(policy)

          if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(policy.responsible_party_id)).first
            responsible_party_address = responsible_party.mailing_address.try(:full_address)
          end

          data = [
          	policy.id,
          	policy.eg_id,
          	responsible_party.try(:full_name),
          	responsible_party.try(:authority_member).try(:ssn),
          	responsible_party.try(:authority_member).try(:dob),
          	responsible_party_address
          ]

          index += 1

          if (index % 100) == 0
            puts "found #{index} policies"
          end

          sheet.row(index).concat data
        rescue Exception => e
          puts policy.id
          puts e.to_s.inspect
        end
      end
    end

    workbook.write "#{Rails.root.to_s}/RP_QHP_Policies#{calender_year}.xls"
  end

  private

  def policies_by_subscriber
    plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i}).map(&:id)
    p_repo = {}

    Person.no_timeout.each do |person|
      person.members.each do |member|
        p_repo[member.hbx_member_id] = person._id
      end
    end

    pols = PolicyStatus::Active.between(Date.new(calender_year-1,12,31), Date.new(calender_year,12,31)).results.where({
      :plan_id => {"$in" => plans}, :employer_id => nil
      }).group_by { |p| p_repo[p.subscriber.m_id] }
  end

  def rejected_policy?(policy)
    edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => policy.id })
    return true if edi_transactions.size == 1 && edi_transactions.first.aasm_state == 'rejected'
    false
  end

  def valid_policy?(policy)
	  active_enrollees = policy.enrollees.reject{|en| en.canceled?}
	  return false if active_enrollees.empty?
	  return false if rejected_policy?(policy) || !policy.belong_to_authority_member? || policy.canceled?
	  return false if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
	  true
	end
end