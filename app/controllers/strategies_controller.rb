class StrategiesController < ApplicationController
  layout "app"
  before_action :set_strategy, except: :index

  def index
    Strategy.ensure_default_for(Current.user)
    strategies = Current.user.strategies.includes(:versions).order(:created_at)
    @active, @archived = strategies.partition { |strategy| !strategy.archived? }
  end

  def edit
    @version = @strategy.current_version
  end

  def update
    @version = @strategy.revise!(params.expect(config: StrategyVersion::DEFAULTS.keys).to_h)
    redirect_to strategies_path, notice: "Saved #{@strategy.name} as version #{@version.number}. Earlier signals keep their original version."
  rescue ActiveRecord::RecordInvalid => error
    @version = error.record
    render :edit, status: :unprocessable_entity
  end

  def toggle
    return redirect_to(strategies_path, alert: "Archived strategies cannot be enabled.") if @strategy.archived?
    @strategy.update!(enabled: !@strategy.enabled)
    redirect_to strategies_path, status: :see_other, notice: "#{@strategy.name} #{@strategy.enabled ? "enabled" : "disabled"}."
  end

  def clone
    name = (1..).lazy.map { |n| n == 1 ? "#{@strategy.name} copy" : "#{@strategy.name} copy #{n}" }.find { |candidate| !Current.user.strategies.exists?(name: candidate) }
    copy = @strategy.clone_as!(name)
    redirect_to strategies_path, status: :see_other, notice: "Created #{copy.name} (disabled). Edit it, then enable it."
  end

  def archive
    @strategy.update!(archived_at: Time.current, enabled: false)
    redirect_to strategies_path, status: :see_other, notice: "#{@strategy.name} archived. Its signals and versions are kept."
  end

  private
    def set_strategy
      @strategy = Current.user.strategies.find(params[:id])
    end
end
