module Admin
  class StoreHoursController < BaseController
    def show
      @config = StoreHours.hours_config
    end

    def update
      permitted = params.require(:store_hours).permit(
        weekday:  [:open, :close],
        saturday: [:open, :close],
        sunday:   [:open, :close],
        holiday:  [:open, :close]
      )
      StoreHours.update_hours(permitted.to_h)
      redirect_to admin_store_hours_path, notice: "Hours updated."
    end
  end
end
