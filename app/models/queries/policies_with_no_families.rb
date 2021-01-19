module Queries
  class PoliciesWithNoFamilies
    
    # returns policies that do not belong to any family
    def execute
      policy_ids = Family.collection.aggregate([
        {"$unwind" => '$households'},
        {"$unwind" => '$households.hbx_enrollments'},
        {
          "$group" => {
            "_id" => {
              "id" => "$households.hbx_enrollments._id"
              },
              "policy_id" => {"$last" => "$households.hbx_enrollments.policy_id"},
            }
            },
            {
              "$project" => {
               "_id" => 1,
               "policy_id" => "$policy_id",
             }
           }
           ]).collect{|r| r['policy_id']}.uniq

      policies = Policy.where(:id.nin => policy_ids).individual_market
    end
  end
end
