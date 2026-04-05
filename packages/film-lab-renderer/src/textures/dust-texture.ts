import * as THREE from "three";

/**
 * 512x512 seamless tileable dust particle texture.
 * White particles on transparent black, suitable for screen blend.
 */
export function createDustTexture(): THREE.CanvasTexture {
  const size = 512;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;

  // Clear to transparent black
  ctx.clearRect(0, 0, size, size);

  // Draw dust particles
  const particleCount = 100;
  for (let i = 0; i < particleCount; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const radius = 0.5 + Math.random() * 2.0;
    const opacity = 0.3 + Math.random() * 0.5;

    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(255, 255, 255, ${opacity})`;
    ctx.fill();

    // Seamless tiling: mirror particles near edges
    const margin = 16;
    if (x < margin) drawMirror(ctx, x + size, y, radius, opacity);
    if (x > size - margin) drawMirror(ctx, x - size, y, radius, opacity);
    if (y < margin) drawMirror(ctx, x, y + size, radius, opacity);
    if (y > size - margin) drawMirror(ctx, x, y - size, radius, opacity);
  }

  // Add some larger soft dust clumps
  for (let i = 0; i < 25; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const radius = 2 + Math.random() * 4;
    const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, `rgba(255, 255, 255, ${0.2 + Math.random() * 0.3})`);
    gradient.addColorStop(1, "rgba(255, 255, 255, 0)");
    ctx.fillStyle = gradient;
    ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}

function drawMirror(
  ctx: CanvasRenderingContext2D,
  x: number, y: number,
  radius: number, opacity: number,
): void {
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fillStyle = `rgba(255, 255, 255, ${opacity})`;
  ctx.fill();
}
