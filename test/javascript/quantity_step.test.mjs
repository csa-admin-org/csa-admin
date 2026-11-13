import assert from "node:assert/strict"
import { test } from "node:test"
import { nextQuantity } from "../../app/javascript/controllers/members/quantity_step.js"

const kg = { step: "0.01", max: "11.02" }
const piece = { step: "1", max: "3" }

test("a fractional kilogram snaps to the next whole kilogram", () => {
  assert.equal(nextQuantity(8.02, -1, kg), 8)
  assert.equal(nextQuantity(8.02, 1, kg), 9)
})

test("a whole kilogram still moves by one", () => {
  assert.equal(nextQuantity(8, -1, kg), 7)
  assert.equal(nextQuantity(8, 1, kg), 9)
})

test("plus stops at stock when the next kilogram does not fit", () => {
  assert.equal(nextQuantity(11, 1, kg), 11.02)
  assert.equal(nextQuantity(11.02, 1, kg), 11.02)
})

test("a quantity under one kilogram floors to zero", () => {
  assert.equal(nextQuantity(0.5, -1, kg), 0)
})

test("pieces still move by one and stop at stock", () => {
  assert.equal(nextQuantity(2, 1, piece), 3)
  assert.equal(nextQuantity(3, 1, piece), 3)
})
