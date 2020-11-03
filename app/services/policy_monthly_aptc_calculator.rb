module Services
  class PolicyMonthlyAptcCalculator
    
    def initialize(policy_disposition:, calender_year:)
    	@policy_disposition = policy_disposition
    	@calender_year = calender_year
    end

    def max_aptc_amounts_by_month
      return @max_aptc_amounts_by_month if defined? @max_aptc_amounts_by_month
    	policy_start_date = @policy_disposition.start_date
    	policy_end_date = @policy_disposition.end_date
      @max_aptc_amounts_by_month = (policy_start_date.month..policy_end_date.month).inject({}) do |premiums_by_month, calender_month|
        premiums_by_month[calender_month] = calculate_max_aptc_for_month(calender_month, @policy_disposition.policy)
        premiums_by_month
    	end
    end

    def calculate_max_aptc_for_month(calender_month, policy)
    	calender_month_begin = Date.new(@calender_year, calender_month, 1)
    	calender_month_end = calender_month_begin.end_of_month
      aptc_dates = if (calender_month_begin..calender_month_end).cover?(@policy_disposition.end_date)
        [@policy_disposition.end_date]
      else
    	  [calender_month_end]
    	end
    	
      aptc_dates << calender_month_begin if @policy_disposition.start_date <= calender_month_begin
      if policy.aptc_credits.count > 0
        policy.aptc_credits.each do |aptc_credit|
          next if aptc_credit.start_on.nil?
          aptc_dates << aptc_credit.start_on if (calender_month_begin..calender_month_end).cover?(aptc_credit.start_on)
          if (calender_month_begin..calender_month_end).cover?(aptc_credit.end_on) && aptc_credit.end_on != calender_month_end
            aptc_dates << (aptc_credit.end_on + 1.day)
          end
        end
      end

      max_aptc_dates = aptc_dates.compact.uniq.sort
      max_aptc_dates.each_with_index.collect do |date, index|
        next if date == max_aptc_dates[-1]
        {
          aptc_start_date: date,
          aptc_end_date: aptc_end_date(max_aptc_dates, index, calender_month_end),
          max_aptc: max_aptc_value(date)
        }
      end.compact
    end

    def aptc_end_date(sorted_aptc_dates, index, calender_month_end)
      if sorted_aptc_dates[index + 1] == calender_month_end
        calender_month_end
      else
        sorted_aptc_dates[index + 1].prev_day
      end
    end

    def max_aptc_value(date)
      policy_aptc_credit = @policy_disposition.policy.aptc_credits.select{|aptc_credit| aptc_credit.start_on == date}.first
      policy_aptc_credit.present? ? policy_aptc_credit.aptc : @policy_disposition.as_of(date).applied_aptc
    end

    def max_aptc_amount_for(calender_month)
      month_aptc_amounts = max_aptc_amounts_by_month[calender_month]
      calender_start_date = Date.new(@calender_year, calender_month, 1)
      calender_end_date = calender_start_date.end_of_month
      calender_days = (calender_start_date..calender_end_date).count
      month_aptc_amounts.sum do |aptc_date_hash|
        (aptc_date_hash[:max_aptc]/calender_days)*(aptc_date_hash[:aptc_start_date]..aptc_date_hash[:aptc_end_date]).count.to_f
      end.round(2)
    end
  end
end
