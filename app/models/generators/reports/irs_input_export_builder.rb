module Generators::Reports  
  class IrsInputExportBuilder

    attr_reader :notice, :data, :multiple

    def initialize(notice, multiple)
      @notice = notice
      @multiple = multiple
    end

    def excel_row
      @data = [ @notice.policy_id, @notice.subscriber_hbx_id, @notice.recipient_address.to_s ]
      append_coverage_household
      @data += [@notice.issuer_name]
      append_premiums
      @data
    end

    def append_covered_member(indiv)
      @data += [indiv.name, indiv.ssn, indiv.dob, indiv.coverage_start_date, indiv.coverage_termination_date]
    end

    def append_coverage_household
      range = 0..4
      range = 5..10 if multiple

      @notice.covered_household[range].each do |indiv|
        append_covered_member(indiv)
      end
      (5 - @notice.covered_household[range].size).times{ append_blank_arr(5) }
    end

    def append_blank_arr(size)
      size.times{ @data << '' }
    end

    def append_premiums
      (1..12).each do |index|
        monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
        if monthly_premium.blank?
          append_blank_arr(3)
        else
          @data += [monthly_premium.premium_amount, monthly_premium.premium_amount_slcsp, monthly_premium.monthly_aptc]
        end
      end
    end

    def clear_variables
      @data   = nil
      @notice = nil
    end
  end
end