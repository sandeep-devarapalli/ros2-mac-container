import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const html = readFileSync(new URL("../docs/index.html", import.meta.url), "utf8");

assert.match(html, /<title>ROS2 Wireless Stream Simulator - Apple Silicon Mac<\/title>/);
assert.match(html, /id="sensorSelect"/);
assert.match(html, /id="compressionSelect"/);
assert.match(html, /id="networkSelect"/);
assert.match(html, /id="simCanvas"/);

const matrixMatch = html.match(/const matrix=(\{[\s\S]*?\});\s*const sensorSelect=/);
assert.ok(matrixMatch, "simulator matrix not found");

const matrix = vm.runInNewContext(`(${matrixMatch[1]})`);
const results = [];

for (const [sensorKey, sensor] of Object.entries(matrix.sensors)) {
  for (const [compressionKey, compression] of Object.entries(sensor.compressions)) {
    for (const [networkKey, network] of Object.entries(matrix.networks)) {
      const saturationRatio = compression.bandwidth / network.capacity;
      let computedLatency = Math.round(compression.baseLatency + network.delayFactor * 8);
      if (saturationRatio > 0.8) {
        computedLatency += Math.round((saturationRatio - 0.8) * 450);
      }

      let statusText = "Excellent";
      if (saturationRatio >= 1) {
        statusText = "Dropping Frame";
      } else if (saturationRatio > 0.7 || network.packetDropChance > 0.1) {
        statusText = "Stalled Packet";
      }

      const packetLoss = Math.min(100, (network.packetDropChance + (saturationRatio >= 1 ? 0.6 : 0)) * 100);

      assert.ok(Number.isFinite(compression.bandwidth) && compression.bandwidth > 0, `${sensorKey}/${compressionKey} bandwidth`);
      assert.ok(Number.isFinite(network.capacity) && network.capacity > 0, `${networkKey} capacity`);
      assert.ok(Number.isFinite(computedLatency) && computedLatency >= 0, `${sensorKey}/${compressionKey}/${networkKey} latency`);
      assert.ok(Number.isFinite(packetLoss) && packetLoss >= 0 && packetLoss <= 100, `${sensorKey}/${compressionKey}/${networkKey} packet loss`);

      results.push({
        sensorKey,
        compressionKey,
        networkKey,
        saturated: saturationRatio >= 1,
        statusText,
      });
    }
  }
}

assert.equal(results.length, 32, "expected 32 simulator combinations");
assert.ok(results.some((result) => result.saturated), "expected at least one saturated combination");
assert.ok(results.some((result) => result.statusText === "Excellent"), "expected at least one excellent combination");
assert.ok(results.some((result) => result.statusText === "Stalled Packet"), "expected at least one stalled combination");
assert.ok(results.some((result) => result.statusText === "Dropping Frame"), "expected at least one dropping-frame combination");

console.log(`Validated ${results.length} simulator combinations in docs/index.html.`);
