import { Controller } from "@hotwired/stimulus"

const PICKER_ZOOM = 17

export default class extends Controller {
  static targets = ["map", "empty", "unavailable", "hint", "geocodeButton", "geocodeStatus"]

  static values = {
    latitude: Number,
    longitude: Number,
    latitudeInputId: String,
    longitudeInputId: String,
    streetInputId: String,
    zipInputId: String,
    cityInputId: String,
    geocodeUrl: String,
    geocodeLoadingMessage: String,
    geocodeUpdatedMessage: String,
    geocodeFailedMessage: String,
    geocodeUnavailableMessage: String,
    markerTitle: String,
    styleUrl: String,
    locale: Object,
    scriptUrl: String,
    stylesheetUrl: String,
    editable: Boolean
  }

  connect() {
    this.disconnected = false
    this.abortController = new AbortController()
    this.bindInputs()

    this.loadMaplibre()
      .then(() => {
        if (this.disconnected || !this.hasMapTarget) return

        this.initializeMap()
      })
      .catch((error) => this.showUnavailable(error))
  }

  disconnect() {
    this.disconnected = true
    this.abortController?.abort()
    this.abortController = null
    this.marker?.remove()
    this.marker = null
    this.map?.remove()
    this.map = null
  }

  initializeMap() {
    const position = this.currentPosition

    this.map = new window.maplibregl.Map({
      container: this.mapTarget,
      style: this.styleUrlValue,
      center: position || [0, 0],
      zoom: position ? PICKER_ZOOM : 1,
      attributionControl: false,
      cooperativeGestures: true,
      locale: this.localeValue
    })
    this.map.addControl(
      new window.maplibregl.AttributionControl({ compact: false }),
      "bottom-right"
    )
    if (this.editableValue) {
      this.map.addControl(
        new window.maplibregl.NavigationControl({ showCompass: false }),
        "top-right"
      )
    }
    if (this.editableValue) {
      this.map.on("click", ({ lngLat }) => this.syncFromMap(lngLat))
    }

    if (position) {
      this.showPosition(position)
    } else {
      this.showEmpty()
    }
  }

  bindInputs() {
    if (!this.editableValue) return

    for (const input of [this.latitudeInput, this.longitudeInput].filter(Boolean)) {
      input.addEventListener("input", () => this.syncFromInputs(), {
        signal: this.abortController.signal
      })
    }
  }

  syncFromInputs() {
    const position = this.currentPosition
    if (position) {
      this.showPosition(position)
    } else {
      this.showEmpty()
    }
  }

  showPosition(position) {
    if (!this.map) {
      this.showUnavailable()
      return
    }

    this.mapTarget.classList.remove("hidden")
    this.map.resize()
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    if (this.hasUnavailableTarget) this.unavailableTarget.classList.add("hidden")
    if (this.hasHintTarget) this.hintTarget.classList.remove("hidden")

    if (!this.marker) {
      this.marker = new window.maplibregl.Marker({
        color: "#16a34a",
        draggable: this.editableValue
      })
        .setLngLat(position)
        .setPopup(new window.maplibregl.Popup({ offset: 16 }).setText(this.markerTitleValue))
        .addTo(this.map)

      this.marker.getElement().setAttribute("aria-label", this.markerTitleValue)
      this.marker.getElement().setAttribute("title", this.markerTitleValue)
      if (this.editableValue) {
        this.marker.on("dragend", () => this.syncFromMarker())
      }
    }

    this.marker.setLngLat(position)
    this.map.setCenter(position)
    this.map.setZoom(PICKER_ZOOM)
  }

  async geocode(event) {
    event.preventDefault()
    event.stopImmediatePropagation()
    if (this.geocoding || !this.hasGeocodeUrlValue) return

    const address = this.currentAddress
    if (!this.geocodableAddress(address)) {
      this.updateGeocodeStatus(this.geocodeUnavailableMessageValue)
      return
    }

    this.geocoding = true
    this.setGeocodingState(true)

    try {
      const response = await fetch(this.geocodeUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ depot: address })
      })
      const payload = await response.json()

      if (!response.ok) throw new Error(payload.error || this.geocodeFailedMessageValue)

      this.updateInputs(Number(payload.latitude), Number(payload.longitude))
      this.updateGeocodeStatus(this.geocodeUpdatedMessageValue)
    } catch (error) {
      this.updateGeocodeStatus(error.message || this.geocodeFailedMessageValue)
    } finally {
      this.geocoding = false
      this.setGeocodingState(false)
    }
  }

  showEmpty() {
    this.marker?.remove()
    this.marker = null
    this.mapTarget.classList.add("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
    if (this.hasUnavailableTarget) this.unavailableTarget.classList.add("hidden")
    if (this.hasHintTarget) this.hintTarget.classList.add("hidden")
  }

  showUnavailable(error = null) {
    if (error) console.warn("Depot coordinate map failed to load", error)

    this.marker?.remove()
    this.marker = null
    this.mapTarget.classList.add("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    if (this.hasHintTarget) this.hintTarget.classList.add("hidden")

    if (this.currentPosition && this.hasUnavailableTarget) {
      this.unavailableTarget.classList.remove("hidden")
    } else if (this.hasEmptyTarget) {
      this.emptyTarget.classList.remove("hidden")
    }
  }

  syncFromMarker() {
    const position = this.marker.getLngLat()
    this.updateInputs(position.lat, position.lng)
  }

  syncFromMap(position) {
    this.updateInputs(position.lat, position.lng)
  }

  updateInputs(latitude, longitude) {
    this.latitudeInput.value = latitude.toFixed(6)
    this.longitudeInput.value = longitude.toFixed(6)
    this.latitudeInput.dispatchEvent(new Event("input", { bubbles: true }))
    this.longitudeInput.dispatchEvent(new Event("input", { bubbles: true }))
  }

  setGeocodingState(geocoding) {
    if (this.hasGeocodeButtonTarget) {
      this.geocodeButtonTarget.disabled = geocoding
      this.geocodeButtonTarget.setAttribute("aria-busy", geocoding ? "true" : "false")
      this.geocodeButtonTarget.classList.toggle("opacity-60", geocoding)
    }
    if (geocoding) this.updateGeocodeStatus(this.geocodeLoadingMessageValue)
  }

  updateGeocodeStatus(message) {
    if (this.hasGeocodeStatusTarget) this.geocodeStatusTarget.textContent = message
  }

  geocodableAddress(address) {
    return [address.street, address.zip, address.city].every((value) => value.trim().length > 0)
  }

  get currentAddress() {
    return {
      street: this.inputValue(this.streetInputIdValue),
      zip: this.inputValue(this.zipInputIdValue),
      city: this.inputValue(this.cityInputIdValue)
    }
  }

  inputValue(id) {
    return document.getElementById(id)?.value || ""
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  get currentPosition() {
    const latitude = this.latitudeInput
      ? Number.parseFloat(this.latitudeInput.value)
      : this.latitudeValue
    const longitude = this.longitudeInput
      ? Number.parseFloat(this.longitudeInput.value)
      : this.longitudeValue
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null

    return [longitude, latitude]
  }

  get latitudeInput() {
    return document.getElementById(this.latitudeInputIdValue)
  }

  get longitudeInput() {
    return document.getElementById(this.longitudeInputIdValue)
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
}
