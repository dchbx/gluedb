class EndCoverage
  include EnrollmentAction::NotificationExemptionHelper

  def initialize(action_factory, policy_repo = Policy)
    @policy_repo = policy_repo
    @action_factory = action_factory
  end

  def execute(request)
    @request = request
    affected_enrollee_ids = @request[:affected_enrollee_ids]
    return if affected_enrollee_ids.empty?

    @policy = @policy_repo.find(request[:policy_id])

    enrollees_not_already_canceled = @policy.enrollees.select { |e| !e.canceled? }

    update_policy(affected_enrollee_ids)
    notify_if_qualifies(request, @policy)

    action = @action_factory.create_for(request)
    action_request = {
      policy_id: @policy.id,
      operation: request[:operation],
      reason: request[:reason],
      affected_enrollee_ids: request[:affected_enrollee_ids],
      include_enrollee_ids: enrollees_not_already_canceled.map(&:m_id),
      current_user: request[:current_user]
    }
    result = action.execute(action_request)
    result
  end

  def execute_csv(request, listener)
    @request = request

    @policy = @policy_repo.where({"_id" => request[:policy_id]}).first

    if (@policy.nil?)
      listener.no_such_policy(policy_id: request[:policy_id])
      listener.fail
      return
    end

    affected_enrollee_ids = @request[:affected_enrollee_ids]

    if (affected_enrollee_ids.nil? || affected_enrollee_ids.empty?)
      listener.fail(subscriber: request[:affected_enrollee_ids])
      return
    end

    if @policy.subscriber.coverage_ended?
      listener.policy_inactive(policy_id: request[:policy_id])
      listener.fail(subscriber: request[:affected_enrollee_ids])
      return
    end

    if request[:reason]== 'terminate' && @policy.enrollees.any?{ |e| e.coverage_start > request[:coverage_end].to_date }
      listener.end_date_invalid(end_date: request[:coverage_end])
      listener.fail(subscriber: request[:affected_enrollee_ids])
      return
    end

    enrollees_not_already_canceltermed= @policy.enrollees.select { |e| !e.canceled? && !e.terminated? }

    begin
      update_policy(affected_enrollee_ids)
    rescue PremiumCalcError => e
      listener.no_contribution_strategy(message: e.message)
      listener.fail(subscriber: request[:affected_enrollee_ids] )
    else
      action = @action_factory.create_for(request)

      action_request =
      {
        policy_id: @policy.id,
        operation: request[:operation],
        reason: request[:reason],
        affected_enrollee_ids: enrollees_not_already_canceltermed.map(&:m_id),
        include_enrollee_ids: enrollees_not_already_canceltermed.map(&:m_id),
        current_user: request[:current_user]
      }

      action.execute(action_request)
      listener.success(subscriber: request[:affected_enrollee_ids])
    end
  end

  private

  def update_policy(affected_enrollee_ids)
    subscriber = @policy.subscriber
    start_date  = @policy.subscriber.coverage_start
    plan = @policy.plan
    skip_recalc = affected_enrollee_ids.include?(subscriber.m_id) && (plan.year >= 2016)

    if @policy.is_shop? && !skip_recalc
      employer = @policy.employer
      strategy = employer.plan_years.detect{|py| py.start_date.year == plan.year}.contribution_strategy
      raise PremiumCalcError, "No contribution data found for #{employer.name} (fein: #{employer.fein}) in plan year #{@policy.plan.year}" if strategy.nil?
      plan_year = employer.plan_year_of(start_date)
      raise PremiumCalcError, "policy start date #{start_date} does not fall into any plan years of #{employer.name} (fein: #{employer.fein})" if plan_year.nil?
    else
      raise PremiumCalcError, "policy start date #{start_date} not in rate table for #{plan.year} plan #{plan.name} with hios #{plan.hios_plan_id} " unless plan.year == start_date.year || (start_date.year >= 2016 && @policy.is_shop?)
    end

    premium_calculator = Premiums::PolicyCalculator.new

    if(affected_enrollee_ids.include?(subscriber.m_id))
      premium_calculator.apply_calculations(@policy) unless skip_recalc
      end_coverage_for_everyone
    else
      end_coverage_for_ids(affected_enrollee_ids)
      enrollees = []
      rejected = @policy.enrollees.select{ |e| e.coverage_status == "inactive" }
      @policy.enrollees.reject!{ |e| e.coverage_status == "inactive" }
      premium_calculator.apply_calculations(@policy)
      active_enrollees = @policy.enrollees.select{ |e| e.coverage_status == "active" }
      enrollees << active_enrollees
      enrollees << rejected
      enrollees.flatten!
      enrollees.each do |e|
        e.policy = nil
      end
      @policy.enrollees.delete_all
      @policy.save!
      enrollees.each do |e|
        @policy.enrollees.build(
            Hash[e.attributes]
          )
      end
    end

    @policy.updated_by = @request[:current_user]
    @policy.save!
  end

  def end_coverage_for_everyone
    select_active(@policy.enrollees).each do |enrollee|
      end_coverage_for(enrollee, @request[:coverage_end])
    end

    @policy.total_premium_amount = final_premium_total
  end

  def end_coverage_for_ids(ids)
    enrollees = ids.map { |id| @policy.enrollee_for_member_id(id) }
    select_active(enrollees).each do |enrollee|
      end_coverage_for(enrollee, @request[:coverage_end])

      @policy.total_premium_amount -= enrollee.pre_amt
    end
  end

  def select_active(enrollees)
    enrollees.select { |e| e.coverage_status == 'active' }
  end

  def final_premium_total
    new_premium_total = 0
    if(@request[:operation] == 'cancel')
      @policy.enrollees.each { |e| new_premium_total += e.pre_amt }
    elsif(@request[:operation] == 'terminate')
      @policy.enrollees.each do |e|
        new_premium_total += e.pre_amt if e.coverage_end == @policy.subscriber.coverage_end
      end
    end
    new_premium_total
  end

  def end_coverage_for(enrollee, date)
    enrollee.coverage_status = 'inactive'
    enrollee.employment_status_code = 'terminated'

    if(@request[:operation] == 'cancel')
      enrollee.coverage_end = enrollee.coverage_start
    else
      enrollee.coverage_end = date
    end
  end

  def notify_if_qualifies(request, policy)
    if(request[:operation] == 'cancel')
      Observers::PolicyUpdated.notify(policy)
    else
      coverage_end_date = parse_coverage_end(request[:coverage_end])
      unless termination_event_exempt_from_notification?(policy, coverage_end_date)
        Observers::PolicyUpdated.notify(policy)
      end
    end
  end

  def parse_coverage_end(requested_coverage_end)
    return requested_coverage_end if requested_coverage_end.kind_of?(Date)
    if requested_coverage_end.split('/').first.size == 2
      Date.strptime(requested_coverage_end,"%m/%d/%Y")
    elsif requested_coverage_end.split('-').first.size == 2
      Date.strptime(requested_coverage_end,"%m-%d-%Y")
    end
  end

  class PremiumCalcError < StandardError

  end
end
