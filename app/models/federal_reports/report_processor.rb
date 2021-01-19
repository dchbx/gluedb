module FederalReports
  class ReportProcessor
    #this class builds the appropriate parameters to be sent to the report uploader

    def self.upload_canceled_reports_for(policy)
      return if policy.federal_transmissions.empty?
      void_params = get_doc_params(policy, "void") 
      ::FederalReports::ReportUploader.new.upload(void_params) # send VOID if current policy is canceled and there are federal transmissions present 
    end
    
    #send CORRECTED 1095 if a transmission is present on a submitted/termed policy, send ORGINIAL if there isn't a transmission present
    def self.upload_active_reports_for(policy)
      if policy.federal_transmissions.present?  
        corrected_params = get_doc_params(policy, "corrected")
        ::FederalReports::ReportUploader.new.upload(corrected_params) 
      else  
        original_params = get_doc_params(policy, "original")
        ::FederalReports::ReportUploader.new.upload(original_params) 
      end
    end


    def self.get_doc_params(policy, type)
      {
        policy_id: policy.id,
        type: type,
        void_cancelled_policy_ids: get_void_canceled_policy_ids_of_subscriber(policy),
        void_active_policy_ids: get_void_active_policy_ids_of_subscriber(policy),
        npt: policy.term_for_np
      } 
    end

    def self.base_conditional(policy)   
      return false if policy.is_shop? 
      return false if policy.coverage_type.to_s.downcase != "health"
      return false if policy.coverage_year.first.year == Time.now.year
      return false if policy.coverage_year.first.year < 2018
      true
    end

    def self.get_void_canceled_policy_ids_of_subscriber(policy)
      policy.subscriber.person.policies.select do |pol|
        base_conditional(pol) && pol.aasm_state == 'canceled' && (policy.policy_start.year == pol.policy_start.year)
      end.map(&:id)
    end
  
    def self.get_void_active_policy_ids_of_subscriber(policy)
      policy.subscriber.person.policies.select do |pol|
        base_conditional(pol) && pol.aasm_state.in?(['submitted','terminated','resubmitted']) && (policy.policy_start.year == pol.policy_start.year)
      end.map(&:id)
    end
  end 
end