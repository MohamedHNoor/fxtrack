# Fixed sample geometry for the public preview. The landing page must never show
# Twelve Data prices (see docs/twelve-data-feasibility.md, retention review).
module LandingHelper
  CANDLE_BODIES = [
    [ 90, false ], [ 130, true ], [ 160, true ], [ 200, false ], [ 110, true ], [ 150, true ], [ 190, false ], [ 220, true ],
    [ 125, true ], [ 160, false ], [ 200, true ], [ 180, true ], [ 210, false ], [ 120, true ], [ 155, true ], [ 200, false ],
    [ 105, true ], [ 150, true ], [ 190, false ], [ 235, true ], [ 120, true ], [ 150, false ], [ 185, true ], [ 135, true ],
    [ 170, false ], [ 205, true ], [ 140, true ], [ 175, false ], [ 215, true ], [ 125, true ], [ 160, false ], [ 190, true ],
    [ 100, true ], [ 140, false ], [ 180, true ], [ 220, true ], [ 130, false ], [ 165, true ]
  ].freeze
  FAST_AVERAGE = "M0 250L50 230L100 265L150 190L200 220L250 165L300 200L350 155L400 175L450 105L500 145L550 120L600 140L650 90L700 65L800 85".freeze
  SLOW_AVERAGE = "M0 270L100 245L200 250L300 220L400 200L500 180L600 145L700 120L800 115".freeze

  def illustrative_candles
    CANDLE_BODIES.each_with_index.map do |(body_top, rising), index|
      { x: 20 * (index + 1), body_top: body_top, wick_top: body_top - 17, rising: rising }
    end
  end

  def illustrative_levels
    [
      [ "Entry", "0.5980", "text-info" ], [ "Stop loss", "0.5960", "text-negative" ], [ "Take profit", "0.6030", "text-positive" ],
      [ "Lot size", "0.058", "text-fg" ], [ "Risk / reward", "1 : 2.5", "text-fg" ], [ "Risk amount", "NZD 20.00", "text-fg" ]
    ]
  end
end
