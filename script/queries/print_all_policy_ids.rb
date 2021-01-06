Policy.collection.raw_aggregate([
  {"$group" => {"_id" => "$eg_id"}},
  {"$out" => "policy_ids"}
])
db = Mongoid::Sessions.default
pols = db[:policy_ids]
pols.find.each do |pol|
  puts pol["_id"]
end
