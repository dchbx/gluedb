last_good_date = Protocols::X12::TransactionSetPremiumPayment.where("carrier_id" => {"$in" => Carrier.all.map(&:id)}).order_by({:created_at => 1}).last.created_at
puts last_good_date.inspect

transmissions = Protocols::X12::Transmission.where(
  {
    "created_at" => {"$gt" => last_good_date},
    "file_name" => /^820_/
  }
)

transmissions.each do |t|
  puts [t.file_name, t.created_at, t.id].inspect
  t.transaction_set_premium_payments.each do |tse|
    tse.body.remove!
    tse.delete
  end
  t.delete
end