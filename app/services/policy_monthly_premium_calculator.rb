module Services
  class PolicyMonthlyPremiumCalculator
    
    def initialize(policy_disposition:, calender_year:, silver_plan: nil)
    	@policy_disposition = policy_disposition
    	@calender_year = calender_year
      @silver_plan = silver_plan
    end

    def premiums_by_months
    	return @premiums_by_months if defined? @premiums_by_months
    	policy_start_date = @policy_disposition.start_date
    	policy_end_date = @policy_disposition.end_date
    	@premiums_by_months = (policy_start_date.month..policy_end_date.month).inject({}) do |premiums_by_month, calender_month|
        premiums_by_month[calender_month] = calculate_premiums_for_month(calender_month, @policy_disposition.policy)
        premiums_by_month
    	end
    end

    def calculate_premiums_for_month(calender_month, policy)
    	calender_month_begin = Date.new(@calender_year, calender_month, 1)
    	calender_month_end = calender_month_begin.end_of_month
      premium_dates = if (calender_month_begin..calender_month_end).cover?(@policy_disposition.end_date)
        [@policy_disposition.end_date]
      else
    	  [calender_month_end]
    	end
    	premium_dates << calender_month_begin if @policy_disposition.start_date <= calender_month_begin
    	policy.enrollees.each do |enrollee|
    	  next if enrollee.canceled? || enrollee.coverage_start.blank?
    	  premium_dates << enrollee.coverage_start if (calender_month_begin..calender_month_end).cover?(enrollee.coverage_start)
        if (calender_month_begin..calender_month_end).cover?(enrollee.coverage_end) && enrollee.coverage_end != calender_month_end
          premium_dates << (enrollee.coverage_end + 1.day)
        end
    	end
      sorted_premium_dates = premium_dates.compact.uniq.sort
    	month_premiums = sorted_premium_dates.each_with_index.collect do |date, index|
    	  next if date == sorted_premium_dates[-1]
    	  {
          premium_start_date: date,
          premium_end_date: premium_end_date(sorted_premium_dates, index, calender_month_end),
          premium: @policy_disposition.as_of(date, @silver_plan).ehb_premium
    	  }
    	end.compact
    end

    def premium_end_date(sorted_premium_dates, index, calender_month_end)
      if sorted_premium_dates[index + 1] == calender_month_end
        calender_month_end
      else
        sorted_premium_dates[index + 1].prev_day
      end
    end

    def ehb_premium_for(calender_month)
    	premiums_by_dates = premiums_by_months[calender_month]
      calender_start_date = Date.new(@calender_year, calender_month, 1)
      calender_end_date = calender_start_date.end_of_month
      calender_days = (calender_start_date..calender_end_date).count
      premiums_by_dates.sum do |premium_date_hash|
        (premium_date_hash[:premium]/calender_days)*(premium_date_hash[:premium_start_date]..premium_date_hash[:premium_end_date]).count.to_f
      end.round(2)
    end
  end
end
