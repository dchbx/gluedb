module EnrollmentAction
  module DependentComparisonHelper
    def dependents_changed?(chunk)
      dependents_added?(chunk) || dependents_dropped?(chunk)
    end

    def dependents_added?(chunk)
      (chunk.last.all_member_ids - chunk.first.all_member_ids).any?
    end

    def dependents_dropped?(chunk)
      (chunk.first.all_member_ids - chunk.last.all_member_ids).any?
    end

    def dependents_added_and_dropped?(chunk)
      dependents_added?(chunk) && dependents_dropped?(chunk) && 
        (chunk.last.all_member_ids - chunk.first.all_member_ids) != (chunk.first.all_member_ids - chunk.last.all_member_ids).any?
    end
  end
end
