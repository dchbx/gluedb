pl = Plan.where(year: 2014).map(&:id)

pol = Policy.where({plan_id: {"$in" => pl}})

ivl = pol.where({employer: nil})

badivl = ivl.select{|p| p.policy_start.year == 2015 unless p.subscriber.nil?}

shop = pol.where({ "employer" => { "$ne" => nil }})
bads = []

badshop = shop.select do |p|
  begin
    p.coverage_year.first.year == 2015 unless p.subscriber.nil?
  rescue
    bads << p
  end
end

bads << badivl
bads << badshop

