class AccountsController < ApplicationController
  before_action :set_account, only: %i[show edit update destroy]
  skip_before_action :verify_authenticity_token, only: %i[add_money withdraw_money]
  before_action :load_account, only: %i[add_money]

  # GET /accounts or /accounts.json
  def index
    @accounts = Account.all
  end

  # GET /accounts/1 or /accounts/1.json
  def show; end

  # GET /accounts/new
  def new
    @account = Account.new
  end

  # GET /accounts/1/edit
  def edit; end

  # POST /accounts or /accounts.json
  def create
    @account = Account.new(account_params)

    respond_to do |format|
      if @account.save
        format.html { redirect_to account_url(@account), notice: 'Account was successfully created.' }
        format.json { render :show, status: :created, location: @account }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /accounts/1 or /accounts/1.json
  def update
    respond_to do |format|
      if @account.update(account_params)
        format.html { redirect_to account_url(@account), notice: 'Account was successfully updated.' }
        format.json { render :show, status: :ok, location: @account }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /accounts/1 or /accounts/1.json
  def destroy
    @account.destroy!

    respond_to do |format|
      format.html { redirect_to accounts_url, notice: 'Account was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def add_money
    money_to_add = params[:money_to_add].to_i
    @account.add_money(money_to_add)
    respond_to do |format|
      if @account.save
        format.json do
          render json: { message: "Added money #{money_to_add} successfully" }
        end
      else
        format.json do
          render json: { message: account.errors.messages }
        end
      end
    end
  end

  def withdraw_money
    money_to_withdraw = params[:money_to_withdraw].to_i
    @account.withdraw_money(money_to_withdraw)
    respond_to do |format|
      if account.save
        format.json do
          render json: { message: "Money withdrawn #{money_to_withdraw} successfully" }
        end
      else
        format.json do
          render json: { message: account.errors.messages }
        end
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_account
    @account = Account.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def account_params
    params.require(:account).permit(:balance)
  end

  def load_account
    @account = Account.find_by(id: params[:id])
    return if @account

    respond_to do |format|
      format.json { render json: { message: 'Invalid account' }, status: :not_found }
    end
  end
end
