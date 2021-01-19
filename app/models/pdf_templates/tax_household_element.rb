 module PdfTemplates
  class TaxHouseholdElement
    include Virtus.model


    attribute :primary, Person
    attribute :spouse, Person
    attribute :dependents, [Person]

    attribute :policies, [Policy]

    
    def coverage_as_of(date)
      coverages = []
      policies.uniq.select do |pol|
        if pol.subscriber.coverage_start > Date.new((date.year - 1),12,31) && pol.subscriber.coverage_start < Date.new(date.year,12,31)
          policy_disposition = PolicyDisposition.new(pol)
          coverages << pol if (policy_disposition.start_date.month..policy_disposition.end_date.month).include?(date.month)
        end
      end

      coverages.map{|x| x.id}
    end
  end
end