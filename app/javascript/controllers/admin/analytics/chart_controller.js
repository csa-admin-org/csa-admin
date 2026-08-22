import { Controller } from "@hotwired/stimulus"

const NBSP = "\u00A0"

const activeYearPlugin = {
  id: "analyticsActiveYear",
  afterBuildTicks(chart, args) {
    if (args.scale?.id !== "x") return

    const active = chart.$analyticsActiveYear
    args.scale.ticks.forEach((tick, index) => {
      tick.major = index === active
    })
  }
}

const openYearFadePlugin = {
  id: "analyticsOpenYearFade",
  afterLayout(chart) {
    delete chart.$openYearFade
    if (chart.config.type !== "line") return

    const openIndex = chart.options.openYearIndex
    const xScale = chart.scales.x
    const count = chart.data.labels?.length || 0
    if (openIndex == null || openIndex !== count - 1 || count < 2 || !xScale) return

    const left = xScale.left
    const right = xScale.right
    const width = right - left
    if (width <= 0) return

    const closed = xScale.getPixelForValue(openIndex - 1)
    const open = xScale.getPixelForValue(openIndex)
    const fadeStart = Math.max(left, Math.min(right, closed + (open - closed) / 2))

    chart.$openYearFade = {
      left,
      right,
      start: (fadeStart - left) / width,
      openIndex
    }
  },
  beforeDatasetsDraw(chart) {
    const fade = chart.$openYearFade
    if (!fade) return

    chart.data.datasets.forEach((dataset, index) => {
      if (!chart.isDatasetVisible(index) || dataset.fill === false) return

      const solid = dataset.backgroundColor
      if (typeof solid !== "string") return

      const faded = fadeRgba(solid, 0.12)
      const line = chart.getDatasetMeta(index).dataset
      if (!faded || !line) return

      const gradient = chart.ctx.createLinearGradient(fade.left, 0, fade.right, 0)
      gradient.addColorStop(0, solid)
      gradient.addColorStop(fade.start, solid)
      gradient.addColorStop(1, faded)
      line.options = { ...line.options, backgroundColor: gradient, borderWidth: 0 }
    })
  },
  afterDatasetsDraw(chart) {
    if (chart.config.type === "bar") {
      strokeOpenYearBars(chart)
      return
    }

    const fade = chart.$openYearFade
    if (!fade) return

    const { ctx } = chart
    chart.data.datasets.forEach((dataset, index) => {
      if (!chart.isDatasetVisible(index)) return

      const line = chart.getDatasetMeta(index).dataset
      const border = typeof dataset.borderColor === "string" ? dataset.borderColor : null
      if (!line || !border) return

      ctx.save()
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.lineWidth = dataset.fill === false ? 2 : 1.5
      strokeLineRange(ctx, line, 0, fade.openIndex - 1, border, [])
      strokeLineRange(
        ctx,
        line,
        fade.openIndex - 1,
        fade.openIndex,
        fadeRgba(border, 0.4) || border,
        [5, 4]
      )
      ctx.restore()
    })
  }
}

function fadeRgba(color, alpha) {
  const match = color.match(/rgba?\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
  if (!match) return null

  return `rgba(${match[1]}, ${match[2]}, ${match[3]}, ${alpha})`
}

function strokeLineRange(ctx, line, start, end, color, dash) {
  if (!line || start < 0 || end <= start) return

  ctx.beginPath()
  ctx.strokeStyle = color
  ctx.setLineDash(dash)
  line.pathSegment(ctx, { start, end }, { move: true })
  ctx.stroke()
}

function strokeOpenYearBars(chart) {
  const openIndex = chart.options.openYearIndex
  const count = chart.data.labels?.length || 0
  if (openIndex == null || openIndex !== count - 1) return

  const columns = new Map()
  chart.data.datasets.forEach((dataset, datasetIndex) => {
    const color = dataset.openYearBorderColor
    if (typeof color !== "string") return

    if (!chart.isDatasetVisible(datasetIndex)) return

    const bar = chart.getDatasetMeta(datasetIndex).data[openIndex]
    if (!bar) return

    const value = dataset.data[openIndex]
    if (value == null || value === 0) return

    const rect = openYearBarRect(bar)
    if (!rect || rect.width <= 1.5 || rect.height <= 1.5) return

    const key = dataset.stack ?? datasetIndex
    const column = columns.get(key) || []
    column.push({ rect, color })
    columns.set(key, column)
  })

  const { ctx } = chart
  ctx.save()
  ctx.lineWidth = 1.5
  ctx.setLineDash([4, 3])
  ctx.lineJoin = "miter"
  ctx.lineCap = "butt"
  columns.forEach((column) => strokeOpenYearColumn(ctx, column))
  ctx.restore()
}

function openYearBarRect(bar) {
  const { x, y, base, width, height, horizontal } = bar.getProps([
    "x",
    "y",
    "base",
    "width",
    "height",
    "horizontal"
  ])
  if (horizontal) {
    return {
      left: Math.min(x, base),
      top: y - height / 2,
      width: Math.abs(x - base),
      height
    }
  }

  return {
    left: x - width / 2,
    top: Math.min(y, base),
    width,
    height: Math.abs(y - base)
  }
}

function strokeOpenYearColumn(ctx, column) {
  const left = Math.min(...column.map(({ rect }) => rect.left))
  const top = Math.min(...column.map(({ rect }) => rect.top))
  const right = Math.max(...column.map(({ rect }) => rect.left + rect.width))
  const bottom = Math.max(...column.map(({ rect }) => rect.top + rect.height))
  const inset = 0.75
  const x0 = left + inset
  const y0 = top + inset
  const x1 = right - inset
  const y1 = bottom - inset
  if (x1 - x0 <= 0 || y1 - y0 <= 0) return

  const topBar = column.reduce((highest, entry) =>
    entry.rect.top < highest.rect.top ? entry : highest
  )

  ctx.strokeStyle = topBar.color
  ctx.beginPath()
  ctx.moveTo(x0, y1)
  ctx.lineTo(x0, y0)
  ctx.lineTo(x1, y0)
  ctx.lineTo(x1, y1)
  ctx.stroke()
}

export default class extends Controller {
  static values = { config: Object }

  connect() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.handleThemeChange = this.handleThemeChange.bind(this)
    this.handleYearEvent = this.handleYearEvent.bind(this)
    this.themeObserver = new MutationObserver(this.handleThemeChange)
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"]
    })
    this.handleMouseLeave = () => this.dispatchYear([])
    this.element.addEventListener("mouseleave", this.handleMouseLeave)
    this.headlinesEl = this.element.closest("[data-controller~='analytics--headlines']")
    this.headlinesEl?.addEventListener("analytics:year", this.handleYearEvent)
    this.activeYearIndex = this.configValue.options?.defaultYearIndex ?? null
    this.renderChart()
  }

  disconnect() {
    this.themeObserver?.disconnect()
    this.element.removeEventListener("mouseleave", this.handleMouseLeave)
    this.headlinesEl?.removeEventListener("analytics:year", this.handleYearEvent)
    this.destroyChart()
  }

  handleThemeChange() {
    this.renderChart()
  }

  handleYearEvent(event) {
    const index = event.detail.index ?? this.configValue.options?.defaultYearIndex ?? null
    if (index === this.activeYearIndex) return

    this.activeYearIndex = index
    this.updateActiveYearTicks()
  }

  async renderChart() {
    const generation = (this.renderGeneration = (this.renderGeneration || 0) + 1)
    this.destroyChart()

    const canvas = this.element.querySelector("canvas")
    if (!canvas) return

    const Chart = await this.chartConstructor()
    // A newer render may have started while chart.js was loading; bail out
    // so we never attach two Chart instances to the same canvas.
    if (generation !== this.renderGeneration || !this.element.isConnected) return

    const config = structuredClone(this.configValue)
    this.applyTheme(config)
    this.applyActiveYearFont(config)
    this.applyNumberFormatting(config)
    this.applySingleYearBars(config)
    this.applyOpenYearFade(config)
    config.plugins = [...(config.plugins || []), activeYearPlugin, openYearFadePlugin]
    config.options.animation = false
    config.options.onHover = (_event, elements) => this.dispatchYear(elements)

    this.chart = new Chart(canvas, config)
    this.chart.$analyticsActiveYear = this.activeYearIndex
    this.chart.update("none")
  }

  async chartConstructor() {
    if (!globalThis.Chart) await import("chart.js")
    return globalThis.Chart
  }

  destroyChart() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  dispatchYear(elements) {
    const index = elements.length ? elements[0].index : null
    if (index === this.lastYearIndex) return

    this.lastYearIndex = index
    this.dispatch("year", { prefix: "analytics", detail: { index } })
  }

  updateActiveYearTicks() {
    if (!this.chart) return

    this.chart.$analyticsActiveYear = this.activeYearIndex
    this.chart.update("none")
  }

  applyActiveYearFont(config) {
    const xScale = config.options.scales?.x
    if (!xScale) return

    // Keep a constant bold weight so switching the active year does not
    // reflow label widths and nudge the whole chart sideways.
    xScale.ticks ||= {}
    xScale.ticks.major = { enabled: true }
    xScale.ticks.font = { weight: "bold", size: 11 }
  }

  applySingleYearBars(config) {
    if (config.type !== "line") return
    if ((config.data?.labels?.length || 0) !== 1) return

    config.type = "bar"
    const stacked = !!config.options.scales?.y?.stacked
    const xScale = config.options.scales?.x || {}
    xScale.offset = true
    xScale.stacked = stacked
    config.options.scales ||= {}
    config.options.scales.x = xScale
    config.options.datasets ||= {}
    config.options.datasets.bar ||= {}
    config.options.datasets.bar.maxBarThickness = 72

    config.data.datasets.forEach((dataset) => {
      const filled = dataset.fill !== false
      dataset.fill = false
      dataset.borderWidth = 0
      dataset.pointRadius = 0
      dataset.tension = 0
      if (filled) {
        dataset.backgroundColor = fadeRgba(dataset.backgroundColor, 0.8) || dataset.backgroundColor
        dataset.hoverBackgroundColor = fadeRgba(dataset.borderColor, 1) || dataset.borderColor
      } else {
        dataset.backgroundColor = dataset.borderColor
        dataset.hoverBackgroundColor = dataset.borderColor
      }
      if (stacked) dataset.stack = "stack"
      delete dataset.segment
    })
  }

  applyOpenYearFade(config) {
    const openIndex = config.options.openYearIndex
    const count = config.data?.labels?.length || 0
    if (openIndex == null || openIndex !== count - 1) return

    if (config.type === "line") {
      if (count < 2) return

      config.data.datasets.forEach((dataset) => {
        dataset.borderWidth = 0
        if (dataset.fill !== false) return

        const solid = typeof dataset.borderColor === "string" ? dataset.borderColor : null
        if (!solid) return

        dataset.pointBackgroundColor = (ctx) =>
          ctx.dataIndex === openIndex ? fadeRgba(solid, 0.4) || solid : solid
      })
      return
    }

    if (config.type !== "bar") return

    config.data.datasets.forEach((dataset) => {
      const solid = dataset.backgroundColor
      if (typeof solid !== "string") return

      const hover =
        typeof dataset.hoverBackgroundColor === "string" ? dataset.hoverBackgroundColor : solid
      const faded = fadeRgba(solid, 0.35) || solid

      dataset.backgroundColor = (ctx) => (ctx.dataIndex === openIndex ? faded : solid)
      dataset.hoverBackgroundColor = (ctx) =>
        ctx.dataIndex === openIndex ? fadeRgba(hover, 0.7) || hover : hover
      dataset.borderWidth = 0
      dataset.openYearBorderColor = fadeRgba(hover, 0.55) || hover
    })
  }

  applyNumberFormatting(config) {
    const yTicks = config.options.scales?.y?.ticks || {}
    const currency = !!yTicks.currency
    const percentage = !!yTicks.percentage
    const stacked = !!config.options.scales?.y?.stacked

    config.options.plugins ||= {}
    config.options.plugins.tooltip ||= {}
    if (stacked) {
      config.options.plugins.tooltip.filter = (item) => {
        const value = item.parsed?.y
        return value != null && value !== 0
      }
      config.options.plugins.tooltip.itemSort = (a, b) => (b.parsed?.y || 0) - (a.parsed?.y || 0)
    }
    config.options.plugins.tooltip.callbacks = {
      ...config.options.plugins.tooltip.callbacks,
      label: (context) => {
        const label = context.dataset.label || ""
        const value = context.parsed.y
        if (value == null) return label

        const formatted = this.formatNumber(value, { currency, percentage })
        if (!stacked || percentage) return `${label}: ${formatted}`

        const total = this.shareTotal(context)
        if (!total) return `${label}: ${formatted}`

        const share = this.formatNumber((value * 100) / total, { percentage: true, precision: 0 })
        return `${label}: ${formatted} (${share})`
      }
    }

    Object.values(config.options.scales || {}).forEach((scale) => {
      const ticks = scale.ticks || {}
      if (ticks.currency) {
        scale.ticks.callback = (value) => this.formatNumber(value, { currency: true, precision: 0 })
      } else if (ticks.percentage) {
        scale.ticks.callback = (value) =>
          this.formatNumber(value, { percentage: true, precision: 0 })
      }
    })
  }

  shareTotal(context) {
    const totals = context.chart.options.shareTotals
    if (Array.isArray(totals)) {
      const total = Number(totals[context.dataIndex])
      return Number.isFinite(total) ? total : 0
    }

    return context.chart.data.datasets.reduce((sum, dataset) => {
      const point = dataset.data[context.dataIndex]
      return sum + (typeof point === "number" ? point : 0)
    }, 0)
  }

  applyTheme(config) {
    const dark = document.documentElement.classList.contains("dark")
    const tick = dark ? "rgb(156, 163, 175)" : "rgb(107, 114, 128)"
    const activeTick = dark ? "rgb(243, 244, 246)" : "rgb(17, 24, 39)"
    const grid = dark ? "rgba(55, 65, 81, 0.5)" : "rgb(229, 231, 235)"
    const legend = dark ? "rgb(209, 213, 219)" : "rgb(55, 65, 81)"
    const fontFamily = getComputedStyle(document.body).fontFamily

    config.options ||= {}
    config.options.font = { ...config.options.font, family: fontFamily }
    config.options.plugins ||= {}
    config.options.plugins.legend ||= {}
    config.options.plugins.legend.labels = {
      ...config.options.plugins.legend.labels,
      color: legend,
      boxWidth: 10,
      usePointStyle: true
    }

    Object.entries(config.options.scales || {}).forEach(([id, scale]) => {
      scale.ticks ||= {}
      scale.grid ||= {}
      scale.grid.color = grid
      if (id === "x") {
        scale.ticks.color = (context) => (context.tick?.major ? activeTick : tick)
      } else {
        scale.ticks.color = tick
      }
    })
  }

  formatNumber(value, { currency = false, percentage = false, precision = null } = {}) {
    if (value == null || Number.isNaN(Number(value))) return ""

    const options = this.configValue.options || {}
    const delimiter = options.numberDelimiter ?? "'"
    const separator = options.numberSeparator ?? "."
    const digits = precision ?? (currency ? 2 : percentage ? 1 : 0)
    const absolute = Math.abs(Number(value))
    const fixed = absolute.toFixed(digits)
    const [integer, fraction] = fixed.split(".")
    const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, delimiter)
    let number = digits > 0 ? `${grouped}${separator}${fraction}` : grouped
    if (Number(value) < 0) number = `-${number}`

    if (percentage) return `${number}%`
    if (!currency) return number

    const unit = this.currencyUnit(options.currencyCode)
    return unit ? `${unit}${NBSP}${number}` : number
  }

  currencyUnit(code) {
    if (!code) return ""
    return code === "EUR" ? "€" : code
  }
}
