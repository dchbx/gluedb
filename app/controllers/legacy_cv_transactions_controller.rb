class LegacyCvTransactionsController < ApplicationController
  def show
    authorize! :read, Policy
    @legacy_cv_transaction = Protocols::LegacyCv::LegacyCvTransaction.find(params[:id])
    @person = @legacy_cv_transaction.policy.subscriber.person 
  end

   def index
    authorize! :read, Policy
    @q = params[:q]
    @qf = params[:qf]
    @qd = params[:qd]

     if params[:q].present?
      @legacy_cv_transactions = Protocols::LegacyCv::LegacyCvTransaction.search(@q, @qf, @qd).page(params[:page]).per(15)
    else
      @legacy_cv_transactions = Protocols::LegacyCv::LegacyCvTransaction.page(params[:page]).per(15)
    end

     respond_to do |format|
      format.html
      format.json { render json: @legacy_cv_transactions }
    end
  end
end
