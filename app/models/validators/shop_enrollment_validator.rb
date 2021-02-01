module Validators
  class ShopEnrollmentValidator
    def initialize(change_request, listener)
      @change_request = change_request
      @listener = listener
    end

    def validate
      provided = @change_request.market
      expected = "shop"
      if(provided != expected)
        @listener.enrollment_not_shop_market({provided: provided, expected: expected})
        return false
      end
      true
    end
  end
end