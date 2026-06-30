import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["map", "primaryInput", "alternativeInput"]

  static values = {
    markers: Array,
    styleUrl: String,
    locale: Object,
    scriptUrl: String,
    stylesheetUrl: String
  }

  connect() {
    this.disconnected = false
    this.abortController = new AbortController()
    this.markerRecords = new Map()
    this.visibleDepotIds = new Set(this.markersValue.map((marker) => String(marker.id)))
    this.panel = this.hasMapTarget ? this.mapTarget.closest(".member-depot-map-panel") : null
    this.observeDisabledState()

    this.loadMaplibre()
      .then(() => {
        if (this.disconnected || !this.hasMapTarget) return

        this.initializeMap()
        this.bindInputs()
        this.syncDisabledState()
      })
      .catch(() => this.hideMap())
  }

  disconnect() {
    this.disconnected = true
    this.abortController?.abort()
    this.abortController = null
    this.disabledStateObserver?.disconnect()
    this.disabledStateObserver = null
    this.markerRecords?.forEach((record) => {
      record.popup?.remove()
      record.marker?.remove()
    })
    this.markerRecords = null
    this.map?.remove()
    this.map = null
  }

  filterMarkers(event) {
    if (event.target.dataset.depotMapFilterScope !== "primary") return

    this.visibleDepotIds = new Set(event.detail.visibleDepotIds.map((id) => String(id)))
    this.markerRecords.forEach((record, depotId) => {
      record.visible = this.visibleDepotIds.has(depotId)
      this.renderMarker(record)
    })
  }

  syncDisabledState() {
    const inputsDisabled =
      this.primaryInputTargets.length > 0 &&
      this.primaryInputTargets.every((input) => input.disabled)
    this.disabled = this.panel?.classList.contains("disabled") || inputsDisabled
    this.panel?.classList.toggle("disabled", this.disabled)
    this.mapTarget.setAttribute("aria-disabled", this.disabled ? "true" : "false")

    if (this.disabled) {
      this.hoveredPrimaryDepotId = null
      this.hoveredAlternativeDepotId = null
      this.closeMarkerPopups()
    }

    this.updateMapInteraction()
    this.updateMarkerStates()
  }

  initializeMap() {
    const position = this.initialPosition

    this.map = new window.maplibregl.Map({
      container: this.mapTarget,
      style: this.styleUrlValue,
      center: position || [0, 0],
      zoom: position ? 13 : 1,
      attributionControl: false,
      cooperativeGestures: true,
      locale: this.localeValue
    })

    for (const marker of this.markersValue) {
      this.addMarker(marker)
    }

    this.map.on("load", () => this.fitBounds())
    this.addControls()
    this.updateMarkerStates()
  }

  addMarker(markerData) {
    const depotId = String(markerData.id)
    const position = [markerData.longitude, markerData.latitude]
    const record = {
      data: markerData,
      depotId,
      position,
      visible: this.visibleDepotIds.has(depotId),
      color: null,
      marker: null,
      popup: null
    }

    this.markerRecords.set(depotId, record)
    this.renderMarker(record)
  }

  renderMarker(record) {
    const state = this.markerState(record.depotId)
    const color = this.markerColor(state)

    if (record.marker) {
      if (record.color !== color) {
        this.updateMarkerColor(record.marker.getElement(), record.color, color)
        record.color = color
      }
    } else {
      record.color = color
      record.marker = this.buildMarker(record, color)
    }

    this.updateMarkerElement(record, state)

    if (record.visible) {
      record.marker.addTo(this.map)
    } else {
      record.popup?.remove()
      record.marker.remove()
    }
  }

  buildMarker(record, color) {
    record.popup = new window.maplibregl.Popup({
      closeButton: false,
      closeOnClick: false,
      focusAfterOpen: false,
      offset: this.markerPopupOffset,
      padding: 8
    }).setText(record.data.title)

    const marker = new window.maplibregl.Marker({ color }).setLngLat(record.position)

    const element = marker.getElement()
    element.setAttribute("aria-label", record.data.title)
    element.addEventListener("click", () => this.selectPrimaryDepot(record.depotId))
    element.addEventListener("mouseenter", () => this.hoverMarker(record))
    element.addEventListener("mouseleave", () => this.clearMarkerHover(record))

    return marker
  }

  get markerPopupOffset() {
    const markerHeight = 42
    const markerRadius = 14
    const linearOffset = 20

    return {
      top: [0, 0],
      "top-left": [0, 0],
      "top-right": [0, 0],
      bottom: [0, -markerHeight],
      "bottom-left": [linearOffset, (markerHeight - markerRadius + linearOffset) * -1],
      "bottom-right": [-linearOffset, (markerHeight - markerRadius + linearOffset) * -1],
      left: [markerRadius, (markerHeight - markerRadius) * -1],
      right: [-markerRadius, (markerHeight - markerRadius) * -1]
    }
  }

  addControls() {
    if ("geolocation" in navigator) {
      const geolocateControl = new window.maplibregl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        trackUserLocation: false,
        showUserHeading: true,
        fitBoundsOptions: { maxZoom: 13 }
      })
      geolocateControl.on("geolocate", (event) => this.fitGeolocationWithClosestDepot(event.coords))
      this.map.addControl(geolocateControl, "top-right")
    }

    this.map.addControl(
      new window.maplibregl.NavigationControl({ showCompass: false }),
      "top-right"
    )
    this.map.addControl(
      new window.maplibregl.AttributionControl({ compact: false }),
      "bottom-right"
    )
  }

  fitGeolocationWithClosestDepot(coords) {
    if (!coords || this.disabled) return

    const userPosition = [coords.longitude, coords.latitude]
    const closestDepot = this.closestVisibleDepotTo(userPosition)
    if (!closestDepot) return

    window.requestAnimationFrame(() => {
      if (!this.map || this.disabled) return

      const bounds = new window.maplibregl.LngLatBounds()
      bounds.extend(userPosition)
      bounds.extend(closestDepot.position)
      this.map.fitBounds(bounds, { padding: 64, maxZoom: 13 })
    })
  }

  closestVisibleDepotTo(position) {
    let closestDepot = null
    let closestDistance = Infinity

    this.markerRecords.forEach((record) => {
      if (!record.visible) return

      const distance = this.distanceBetween(position, record.position)
      if (distance < closestDistance) {
        closestDepot = record
        closestDistance = distance
      }
    })

    return closestDepot
  }

  distanceBetween(firstPosition, secondPosition) {
    const degreesToRadians = Math.PI / 180
    const firstLatitude = firstPosition[1] * degreesToRadians
    const secondLatitude = secondPosition[1] * degreesToRadians
    const latitudeDelta = (secondPosition[1] - firstPosition[1]) * degreesToRadians
    const longitudeDelta = (secondPosition[0] - firstPosition[0]) * degreesToRadians

    const haversine =
      Math.sin(latitudeDelta / 2) ** 2 +
      Math.cos(firstLatitude) * Math.cos(secondLatitude) * Math.sin(longitudeDelta / 2) ** 2

    return haversine
  }

  fitBounds() {
    this.fitMarkerRecords(this.visibleMarkerRecords())
  }

  fitDepotIntoView(depotId) {
    if (this.disabled) return

    const record = this.markerRecords?.get(String(depotId))
    if (!record?.visible || !this.map) return

    window.requestAnimationFrame(() => {
      if (!this.map || this.disabled) return

      const currentBounds = this.map.getBounds()
      if (currentBounds.contains(record.position)) return

      this.fitMarkerRecords(this.visibleMarkerRecords())
    })
  }

  fitMarkerRecords(records) {
    if (records.length === 0) return

    if (records.length === 1) {
      this.map.setCenter(records[0].position)
      this.map.setZoom(13)
    } else {
      const bounds = new window.maplibregl.LngLatBounds()
      for (const record of records) bounds.extend(record.position)
      this.map.fitBounds(bounds, { padding: 48, maxZoom: 13 })
    }
  }

  visibleMarkerRecords() {
    return Array.from(this.markerRecords.values()).filter((record) => record.visible)
  }

  bindInputs() {
    for (const input of this.primaryInputTargets) {
      this.bindInput(input, "primary")
    }
    for (const input of this.alternativeInputTargets) {
      this.bindInput(input, "alternative")
    }
    this.updateMarkerStates()
  }

  bindInput(input, type) {
    const signal = this.abortController.signal
    const enter = () => this.setHoveredDepot(type, input.value)
    const leave = () => this.setHoveredDepot(type, null)
    const update = () => {
      this.syncDisabledState()
      if (input.checked) this.fitDepotIntoView(input.value)
    }

    input.addEventListener("change", update, { signal })
    input.addEventListener("focus", enter, { signal })
    input.addEventListener("blur", leave, { signal })

    const label = input.closest("label")
    if (!label) return

    label.addEventListener("mouseenter", enter, { signal })
    label.addEventListener("mouseleave", leave, { signal })
  }

  hoverMarker(record) {
    this.setHoveredDepot("primary", record.depotId)
    this.openMarkerPopup(record)
  }

  clearMarkerHover(record) {
    this.setHoveredDepot("primary", null)
    record.popup?.remove()
  }

  openMarkerPopup(record) {
    if (!this.map || this.disabled) return

    record.popup?.setLngLat(record.position).addTo(this.map)
  }

  closeMarkerPopups() {
    this.markerRecords?.forEach((record) => record.popup?.remove())
  }

  setHoveredDepot(type, depotId) {
    if (this.disabled) return

    if (type === "primary") {
      this.hoveredPrimaryDepotId = depotId && String(depotId)
    } else {
      this.hoveredAlternativeDepotId = depotId && String(depotId)
    }
    this.updateMarkerStates()

    if (depotId) this.fitDepotIntoView(depotId)
  }

  selectPrimaryDepot(depotId) {
    const input = this.primaryInputTargets.find((input) => input.value === depotId)
    if (!input || input.disabled) return

    input.checked = true
    this.dispatchInputEvents(input)
    this.updateMarkerStates()
    this.fitDepotIntoView(depotId)
    this.queueDepotInputScroll(depotId)
  }

  dispatchInputEvents(input) {
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  queueDepotInputScroll(depotId) {
    window.requestAnimationFrame(() => this.scrollDepotInputIntoView(depotId))
  }

  scrollDepotInputIntoView(depotId) {
    if (this.disabled) return

    const input = this.primaryInputTargets.find((input) => input.value === String(depotId))
    const label = input?.closest("label")
    if (!label || label.offsetParent === null) return

    const margin = 12
    const topLimit = this.stickyScrollOffset() + margin
    const bottomLimit = window.innerHeight - margin
    const rect = label.getBoundingClientRect()

    if (rect.top >= topLimit && rect.bottom <= bottomLimit) return

    window.scrollTo({
      top: Math.max(0, rect.top + window.scrollY - topLimit),
      behavior: "smooth"
    })
  }

  stickyScrollOffset() {
    const styles = getComputedStyle(this.element)
    const sectionNavHeight =
      Number.parseFloat(styles.getPropertyValue("--member-form-section-nav-height")) || 0
    const stickyHeader = this.mapTarget.closest(".member-depot-picker-sticky")
    const depotPickerHeight =
      stickyHeader && getComputedStyle(stickyHeader).position === "sticky"
        ? stickyHeader.getBoundingClientRect().height
        : 0

    return sectionNavHeight + depotPickerHeight
  }

  updateMarkerStates() {
    if (!this.markerRecords) return

    this.markerRecords.forEach((record) => this.renderMarker(record))
    this.updateOptionHighlights()
  }

  observeDisabledState() {
    if (!this.panel) return

    this.disabledStateObserver = new MutationObserver(() => this.syncDisabledState())
    this.disabledStateObserver.observe(this.panel, { attributes: true, attributeFilter: ["class"] })
  }

  updateMarkerColor(element, oldColor, color) {
    const fillElements = Array.from(element.querySelectorAll("svg [fill]"))
    const oldColorValue = oldColor?.toLowerCase()
    let updated = false

    for (const fillElement of fillElements) {
      if (fillElement.getAttribute("fill")?.toLowerCase() === oldColorValue) {
        fillElement.setAttribute("fill", color)
        updated = true
      }
    }

    if (updated) return

    const preservedFills = new Set(["none", "#000", "#000000", "black", "#fff", "#ffffff", "white"])
    const markerFill = fillElements.find((fillElement) => {
      const fill = fillElement.getAttribute("fill")?.toLowerCase()
      return fill && !preservedFills.has(fill)
    })
    markerFill?.setAttribute("fill", color)
  }

  updateMapInteraction() {
    if (!this.map) return

    const interactionMethods = [
      this.map.boxZoom,
      this.map.doubleClickZoom,
      this.map.dragPan,
      this.map.dragRotate,
      this.map.keyboard,
      this.map.scrollZoom,
      this.map.touchZoomRotate
    ]

    for (const method of interactionMethods) {
      if (this.disabled) method.disable()
      else method.enable()
    }
  }

  updateMarkerElement(record, state) {
    const element = record.marker.getElement()
    element.dataset.depotMapState = state
    element.style.zIndex = this.markerZIndex(state)
  }

  updateOptionHighlights() {
    const highlightedDepotIds = new Set(
      [this.hoveredPrimaryDepotId, this.hoveredAlternativeDepotId].filter(Boolean)
    )

    for (const input of [...this.primaryInputTargets, ...this.alternativeInputTargets]) {
      input
        .closest("label")
        ?.classList.toggle("depot-map-highlight", highlightedDepotIds.has(String(input.value)))
    }
  }

  markerState(depotId) {
    if (this.selectedPrimaryDepotId === depotId) return "selected-primary"
    if (this.hoveredPrimaryDepotId === depotId) return "hovered-primary"
    if (this.alternativeDepotIds.has(depotId)) return "selected-alternative"
    if (this.hoveredAlternativeDepotId === depotId) return "hovered-alternative"

    return "default"
  }

  markerColor(state) {
    return this.colors[state] || this.colors.default
  }

  markerZIndex(state) {
    return {
      "selected-primary": 40,
      "hovered-primary": 30,
      "selected-alternative": 20,
      "hovered-alternative": 10,
      default: 0
    }[state]
  }

  get selectedPrimaryDepotId() {
    return this.primaryInputTargets.find((input) => input.checked)?.value
  }

  get alternativeDepotIds() {
    return new Set(
      this.alternativeInputTargets
        .filter((input) => input.checked && !input.disabled)
        .map((input) => input.value)
    )
  }

  get initialPosition() {
    const marker = this.markersValue[0]
    if (!marker) return null

    return [marker.longitude, marker.latitude]
  }

  get colors() {
    const styles = getComputedStyle(this.mapTarget)
    return {
      default: styles.getPropertyValue("--depot-map-marker-default").trim() || "#6b7280",
      "selected-primary": styles.getPropertyValue("--depot-map-marker-primary").trim() || "#16a34a",
      "hovered-primary":
        styles.getPropertyValue("--depot-map-marker-primary-hover").trim() || "#4ade80",
      "selected-alternative":
        styles.getPropertyValue("--depot-map-marker-alternative").trim() || "#86efac",
      "hovered-alternative":
        styles.getPropertyValue("--depot-map-marker-alternative-hover").trim() || "#bbf7d0"
    }
  }

  loadMaplibre() {
    this.loadStylesheet()
    if (window.maplibregl) return Promise.resolve()
    if (window.maplibreLoading) return window.maplibreLoading

    window.maplibreLoading = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = this.scriptUrlValue
      script.async = true
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })

    return window.maplibreLoading
  }

  loadStylesheet() {
    if (document.querySelector(`link[href="${this.stylesheetUrlValue}"]`)) return

    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = this.stylesheetUrlValue
    document.head.appendChild(link)
  }

  hideMap() {
    if (this.hasMapTarget) {
      this.mapTarget.closest(".member-depot-map-panel")?.classList.add("hidden")
    }
  }
}
