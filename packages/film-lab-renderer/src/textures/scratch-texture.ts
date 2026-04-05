import * as THREE from "three";

/**
 * 256x1024 seamless tileable scratch overlay texture.
 * White vertical/diagonal lines on transparent black, suitable for additive blend.
 */
export function createScratchTexture(): THREE.CanvasTexture {
  const width = 256;
  const height = 1024;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d")!;

  ctx.clearRect(0, 0, width, height);

  // Nearly vertical scratches
  for (let i = 0; i < 20; i++) {
    const x = Math.random() * width;
    const angle = (Math.random() - 0.5) * 0.15; // +/-~4.3 degrees from vertical
    const lineWidth = 0.5 + Math.random() * 1.0;
    const opacity = 0.2 + Math.random() * 0.4;

    ctx.save();
    ctx.translate(x, 0);
    ctx.rotate(angle);
    ctx.strokeStyle = `rgba(255, 255, 255, ${opacity})`;
    ctx.lineWidth = lineWidth;
    ctx.beginPath();
    ctx.moveTo(0, -50);
    ctx.lineTo(0, height + 50);
    ctx.stroke();
    ctx.restore();
  }

  // Diagonal scratches (fewer, lower opacity)
  for (let i = 0; i < 8; i++) {
    const x = Math.random() * width;
    const angle = (0.3 + Math.random() * 0.3) * (Math.random() > 0.5 ? 1 : -1);
    const lineWidth = 0.3 + Math.random() * 0.8;
    const opacity = 0.1 + Math.random() * 0.25;
    const segmentLength = 200 + Math.random() * 400;
    const startY = Math.random() * height;

    ctx.save();
    ctx.translate(x, startY);
    ctx.rotate(angle);
    ctx.strokeStyle = `rgba(255, 255, 255, ${opacity})`;
    ctx.lineWidth = lineWidth;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(0, segmentLength);
    ctx.stroke();
    ctx.restore();
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}
