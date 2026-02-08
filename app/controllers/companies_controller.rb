class CompaniesController < ApplicationController
  def index
    @companies = Company.order(:id).all
  end

  def show
    @company = Company.find(params[:id])
    @inventories = @company.inventories.order(:id).page(params[:page]).per(100)
  end
end
