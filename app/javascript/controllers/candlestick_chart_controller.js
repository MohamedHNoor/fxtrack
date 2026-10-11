import { Controller } from "@hotwired/stimulus"
import { createChart, CandlestickSeries } from "lightweight-charts"

// Renders completed candles supplied by the server as a data attribute.
export default class extends Controller {
  static values = { series: Array, precision: Number }

  connect() {
    const styles = getComputedStyle(document.documentElement)
    const color = (name) => styles.getPropertyValue(`--color-${name}`).trim()

    this.chart = createChart(this.element, {
      autoSize: true,
      layout: { background: { color: "transparent" }, textColor: color("muted"), attributionLogo: true },
      grid: { vertLines: { color: color("line") }, horzLines: { color: color("line") } },
      rightPriceScale: { borderColor: color("line") },
      timeScale: { borderColor: color("line"), timeVisible: true, secondsVisible: false },
    })
    const minMove = 1 / 10 ** this.precisionValue
    this.chart.addSeries(CandlestickSeries, {
      upColor: color("positive"), borderUpColor: color("positive"), wickUpColor: color("positive"),
      downColor: color("negative"), borderDownColor: color("negative"), wickDownColor: color("negative"),
      priceFormat: { type: "price", precision: this.precisionValue, minMove },
    }).setData(this.seriesValue)
    this.chart.timeScale().fitContent()
  }

  disconnect() {
    this.chart?.remove()
  }
}
