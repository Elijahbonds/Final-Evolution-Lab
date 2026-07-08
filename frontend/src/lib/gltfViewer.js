/*
 * gltfViewer.js — Tiny dependency-free glTF 2.0 viewer.
 *
 * We deliberately do NOT pull in three.js (not a frontend dep — see
 * package.json). This is a minimal raw-WebGL renderer for simple glTF meshes
 * (indexed POSITION + NORMAL, embedded data-URI buffers, one PBR-ish material)
 * with an eased orbit camera and material-aware ambient + key/fill/rim lighting
 * with a specular term and a subtle image-based-lighting-style environment tint.
 *
 * Scope: enough to render the CC0 Study Cube, Facet Gem, Aurora Prism and
 * similar low-poly CC0 models. Not a full glTF implementation. Falls back
 * gracefully (throws) so callers can render a static preview instead.
 *
 * Enhancements over the core pass:
 *   - PBR-ish shading: baseColor + metallic + roughness -> specular highlight
 *   - Three-light rig (key / fill / rim) + hemispheric environment ambient
 *   - Eased orbit (yaw/pitch/dist lerp) + drag inertia + animated zoom
 *   - Auto-fit: bounding box centers + frames the model, no matter its scale
 *   - Auto-rotate that respects prefers-reduced-motion
 *   - Optional environment tint via opts (defaults to the cyan/purple theme)
 */

function decodeDataUri(uri) {
  const marker = 'base64,';
  const i = uri.indexOf(marker);
  const b64 = i >= 0 ? uri.slice(i + marker.length) : uri;
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let k = 0; k < bin.length; k++) bytes[k] = bin.charCodeAt(k);
  return bytes.buffer;
}

const COMPONENT = { 5121: Uint8Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array };
const NUMCOMP = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 };

function readAccessor(gltf, buffers, index) {
  const acc = gltf.accessors[index];
  const view = gltf.bufferViews[acc.bufferView];
  const buf = buffers[view.buffer];
  const TypedArray = COMPONENT[acc.componentType];
  const offset = (view.byteOffset || 0) + (acc.byteOffset || 0);
  const count = acc.count * NUMCOMP[acc.type];
  return new TypedArray(buf, offset, count);
}

// ── minimal mat4 ───────────────────────────────────────────────────────────
const M = {
  identity: () => new Float32Array([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]),
  perspective(fovy, aspect, near, far) {
    const f = 1 / Math.tan(fovy / 2), nf = 1 / (near - far);
    return new Float32Array([
      f/aspect,0,0,0, 0,f,0,0, 0,0,(far+near)*nf,-1, 0,0,2*far*near*nf,0]);
  },
  multiply(a, b) {
    const o = new Float32Array(16);
    for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++) {
      let s = 0; for (let k = 0; k < 4; k++) s += a[k*4+r]*b[c*4+k]; o[c*4+r] = s;
    }
    return o;
  },
  translate(x, y, z) { const m = M.identity(); m[12]=x; m[13]=y; m[14]=z; return m; },
  scale(s) { const m = M.identity(); m[0]=s; m[5]=s; m[10]=s; return m; },
  rotateX(a) { const c=Math.cos(a),s=Math.sin(a),m=M.identity(); m[5]=c;m[6]=s;m[9]=-s;m[10]=c; return m; },
  rotateY(a) { const c=Math.cos(a),s=Math.sin(a),m=M.identity(); m[0]=c;m[2]=-s;m[8]=s;m[10]=c; return m; },
  normalMat3(m) { // upper-left 3x3 (uniform scale assumed) -> mat3
    return new Float32Array([m[0],m[1],m[2], m[4],m[5],m[6], m[8],m[9],m[10]]);
  },
};

const VERT = `
attribute vec3 aPos; attribute vec3 aNormal;
uniform mat4 uProj; uniform mat4 uView; uniform mat4 uModel; uniform mat3 uNormal;
varying vec3 vNormal; varying vec3 vWorldPos;
void main(){
  vNormal = normalize(uNormal * aNormal);
  vec4 world = uModel * vec4(aPos, 1.0);
  vWorldPos = world.xyz;
  gl_Position = uProj * uView * world;
}`;

// Material-aware, PBR-ish shading. Not a full BRDF — a compact approximation:
// energy-conserving diffuse tinted toward baseColor, a Blinn-Phong specular
// whose sharpness/strength derives from roughness/metalness, plus a Fresnel
// rim and a hemispheric environment ambient tinted by the scene theme.
const FRAG = `
precision mediump float;
varying vec3 vNormal; varying vec3 vWorldPos;
uniform vec3 uColor;
uniform float uMetallic;
uniform float uRoughness;
uniform vec3 uCamPos;
uniform vec3 uSkyTint;    // environment top (theme accent)
uniform vec3 uGroundTint; // environment bottom (deep bg)

void main(){
  vec3 N = normalize(vNormal);
  vec3 V = normalize(uCamPos - vWorldPos);

  // Three-light studio rig.
  vec3 keyDir  = normalize(vec3( 0.5, 0.85, 0.65));
  vec3 fillDir = normalize(vec3(-0.65, 0.25, -0.4));
  vec3 rimDir  = normalize(vec3( 0.0, -0.3,  -1.0));
  vec3 keyCol  = vec3(1.0, 0.98, 0.94);
  vec3 fillCol = uSkyTint;

  float key  = max(dot(N, keyDir),  0.0);
  float fill = max(dot(N, fillDir), 0.0) * 0.45;
  // Rim / Fresnel edge light for a premium silhouette.
  float fres = pow(1.0 - max(dot(N, V), 0.0), 3.0);
  float rim  = max(dot(N, rimDir), 0.0) * fres;

  // Hemispheric image-based-lighting-style ambient.
  float hemi = N.y * 0.5 + 0.5;
  vec3 envAmbient = mix(uGroundTint, uSkyTint, hemi);

  // Diffuse: metals have little diffuse; dielectrics keep their albedo.
  float diffAmt = 1.0 - uMetallic * 0.85;
  vec3 diffuse = uColor * (0.30 + key * keyCol + fill * fillCol) * diffAmt;

  // Specular: Blinn-Phong, sharpness from roughness, tint from metalness.
  vec3 H = normalize(keyDir + V);
  float shininess = mix(4.0, 128.0, 1.0 - clamp(uRoughness, 0.04, 1.0));
  float spec = pow(max(dot(N, H), 0.0), shininess);
  // Metals tint their specular by the base color; dielectrics stay white.
  vec3 specTint = mix(vec3(1.0), uColor, uMetallic);
  vec3 specular = specTint * spec * (0.35 + uMetallic * 0.65);

  vec3 lit = diffuse + envAmbient * uColor * 0.35 + specular;
  lit += uSkyTint * rim * 0.9;             // rim glow
  lit = mix(lit, lit + envAmbient * 0.12, fres); // fresnel env pickup

  // Gentle filmic-ish tonemap + gamma for a richer look.
  lit = lit / (lit + vec3(0.85));
  lit = pow(lit, vec3(1.0 / 2.2));
  gl_FragColor = vec4(lit, 1.0);
}`;

function compile(gl, type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src); gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS))
    throw new Error('shader: ' + gl.getShaderInfoLog(s));
  return s;
}

function prefersReducedMotion() {
  try {
    return window.matchMedia &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch (e) { return false; }
}

// Bounding box over a flat POSITION array -> {center:[x,y,z], radius}
function computeBounds(positions) {
  let minX = Infinity, minY = Infinity, minZ = Infinity;
  let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;
  for (let i = 0; i + 2 < positions.length; i += 3) {
    const x = positions[i], y = positions[i + 1], z = positions[i + 2];
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
    if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
  }
  if (!isFinite(minX)) return { center: [0, 0, 0], radius: 1 };
  const center = [(minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2];
  const rx = (maxX - minX) / 2, ry = (maxY - minY) / 2, rz = (maxZ - minZ) / 2;
  const radius = Math.max(Math.sqrt(rx * rx + ry * ry + rz * rz), 1e-3);
  return { center, radius };
}

/**
 * Mount an interactive glTF viewer on a canvas.
 * @param {HTMLCanvasElement} canvas
 * @param {object} gltf  parsed glTF 2.0 JSON with embedded buffers
 * @param {object} [opts] { skyTint:[r,g,b], groundTint:[r,g,b], autoRotate:bool }
 * @returns {{dispose:()=>void}}
 */
export function mountGltfViewer(canvas, gltf, opts = {}) {
  const gl = canvas.getContext('webgl', { antialias: true, alpha: true });
  if (!gl) throw new Error('WebGL unavailable');

  const buffers = gltf.buffers.map((b) => decodeDataUri(b.uri));
  const prim = gltf.meshes[0].primitives[0];
  const positions = readAccessor(gltf, buffers, prim.attributes.POSITION);
  const normals = prim.attributes.NORMAL != null
    ? readAccessor(gltf, buffers, prim.attributes.NORMAL) : positions;
  const indices = readAccessor(gltf, buffers, prim.indices);
  const mat = gltf.materials?.[prim.material]?.pbrMetallicRoughness;
  const color = mat?.baseColorFactor?.slice(0, 3) || [0.0, 0.83, 1.0];
  const metallic = mat?.metallicFactor != null ? mat.metallicFactor : 0.25;
  const roughness = mat?.roughnessFactor != null ? mat.roughnessFactor : 0.5;

  // Theme environment tint (cyan sky, deep-navy ground) — overridable.
  const skyTint = opts.skyTint || [0.0, 0.55, 0.85];
  const groundTint = opts.groundTint || [0.02, 0.04, 0.10];

  // Frame the model regardless of authored scale/offset.
  const { center, radius } = computeBounds(positions);

  const prog = gl.createProgram();
  gl.attachShader(prog, compile(gl, gl.VERTEX_SHADER, VERT));
  gl.attachShader(prog, compile(gl, gl.FRAGMENT_SHADER, FRAG));
  gl.linkProgram(prog); gl.useProgram(prog);

  const posBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, posBuf);
  gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);
  const aPos = gl.getAttribLocation(prog, 'aPos');
  gl.enableVertexAttribArray(aPos); gl.vertexAttribPointer(aPos, 3, gl.FLOAT, false, 0, 0);

  const nrmBuf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, nrmBuf);
  gl.bufferData(gl.ARRAY_BUFFER, normals, gl.STATIC_DRAW);
  const aNormal = gl.getAttribLocation(prog, 'aNormal');
  gl.enableVertexAttribArray(aNormal); gl.vertexAttribPointer(aNormal, 3, gl.FLOAT, false, 0, 0);

  const idxBuf = gl.createBuffer();
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, idxBuf);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);
  const idxType = indices instanceof Uint32Array ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT;

  const U = (n) => gl.getUniformLocation(prog, n);
  const uProj = U('uProj'), uView = U('uView'), uModel = U('uModel'), uNormal = U('uNormal');
  gl.uniform3fv(U('uColor'), new Float32Array(color));
  gl.uniform1f(U('uMetallic'), metallic);
  gl.uniform1f(U('uRoughness'), roughness);
  gl.uniform3fv(U('uSkyTint'), new Float32Array(skyTint));
  gl.uniform3fv(U('uGroundTint'), new Float32Array(groundTint));
  const uCamPos = U('uCamPos');

  gl.enable(gl.DEPTH_TEST);
  gl.clearColor(0, 0, 0, 0);

  // Distance that frames a sphere of `radius` at ~45° fovy with headroom.
  const fitDist = Math.max(2.2, (radius / Math.tan(Math.PI / 8)) * 1.35);
  const minDist = radius * 1.4, maxDist = radius * 8;

  // Orbit state uses target + current for eased interpolation.
  let yaw = 0.6, pitch = 0.42, dist = fitDist;
  let tYaw = yaw, tPitch = pitch, tDist = dist;
  let dragging = false, lastX = 0, lastY = 0, autoUser = true;
  let velYaw = 0, velPitch = 0; // inertia after release

  const clampPitch = (p) => Math.max(-1.35, Math.min(1.35, p));

  const onDown = (e) => {
    dragging = true; autoUser = false; velYaw = 0; velPitch = 0;
    const p = e.touches ? e.touches[0] : e; lastX = p.clientX; lastY = p.clientY;
  };
  const onUp = () => { dragging = false; };
  const onMove = (e) => {
    if (!dragging) return;
    const p = e.touches ? e.touches[0] : e;
    const dx = (p.clientX - lastX) * 0.01, dy = (p.clientY - lastY) * 0.01;
    tYaw += dx; tPitch = clampPitch(tPitch + dy);
    velYaw = dx; velPitch = dy;
    lastX = p.clientX; lastY = p.clientY;
    if (e.touches) e.preventDefault();
  };
  const onWheel = (e) => {
    tDist = Math.max(minDist, Math.min(maxDist, tDist + e.deltaY * 0.01 * radius));
    e.preventDefault();
  };
  // Keyboard orbit for accessibility (canvas is focusable).
  const onKey = (e) => {
    const step = 0.18;
    if (e.key === 'ArrowLeft') { tYaw -= step; autoUser = false; }
    else if (e.key === 'ArrowRight') { tYaw += step; autoUser = false; }
    else if (e.key === 'ArrowUp') { tPitch = clampPitch(tPitch + step); autoUser = false; }
    else if (e.key === 'ArrowDown') { tPitch = clampPitch(tPitch - step); autoUser = false; }
    else if (e.key === '+' || e.key === '=') { tDist = Math.max(minDist, tDist - radius * 0.4); }
    else if (e.key === '-' || e.key === '_') { tDist = Math.min(maxDist, tDist + radius * 0.4); }
    else return;
    e.preventDefault();
  };

  canvas.addEventListener('mousedown', onDown);
  window.addEventListener('mouseup', onUp);
  window.addEventListener('mousemove', onMove);
  canvas.addEventListener('touchstart', onDown, { passive: false });
  window.addEventListener('touchend', onUp);
  canvas.addEventListener('touchmove', onMove, { passive: false });
  canvas.addEventListener('wheel', onWheel, { passive: false });
  canvas.addEventListener('keydown', onKey);

  let raf = 0;
  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth * dpr, h = canvas.clientHeight * dpr;
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    gl.viewport(0, 0, canvas.width, canvas.height);
  }

  const LERP = 0.14; // eased follow factor

  function frame() {
    resize();
    const reduced = prefersReducedMotion();

    // Apply inertia when not dragging (skipped under reduced-motion).
    if (!dragging && !reduced) {
      if (Math.abs(velYaw) > 1e-4 || Math.abs(velPitch) > 1e-4) {
        tYaw += velYaw; tPitch = clampPitch(tPitch + velPitch);
        velYaw *= 0.92; velPitch *= 0.92;
      }
      // Auto-rotate resumes if the user isn't steering and inertia settled.
      if (autoUser && Math.abs(velYaw) < 1e-3) tYaw += 0.004;
    }

    // Ease current toward target (instant snap under reduced-motion).
    const k = reduced ? 1 : LERP;
    yaw += (tYaw - yaw) * k;
    pitch += (tPitch - pitch) * k;
    dist += (tDist - dist) * k;

    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    const aspect = canvas.width / Math.max(1, canvas.height);
    gl.uniformMatrix4fv(uProj, false, M.perspective(Math.PI / 4, aspect, 0.05, 200));

    // View: pull back by dist, then orbit.
    let view = M.translate(0, 0, -dist);
    view = M.multiply(view, M.rotateX(pitch));
    view = M.multiply(view, M.rotateY(yaw));
    gl.uniformMatrix4fv(uView, false, view);

    // Model: center the geometry at the origin.
    const model = M.translate(-center[0], -center[1], -center[2]);
    gl.uniformMatrix4fv(uModel, false, model);
    gl.uniformMatrix3fv(uNormal, false, M.normalMat3(model));

    // Camera world position (inverse of the orbit) for specular/rim.
    const cx = Math.sin(yaw) * Math.cos(pitch) * dist;
    const cy = Math.sin(pitch) * dist;
    const cz = Math.cos(yaw) * Math.cos(pitch) * dist;
    gl.uniform3f(uCamPos, cx + center[0], cy + center[1], cz + center[2]);

    gl.drawElements(gl.TRIANGLES, indices.length, idxType, 0);
    raf = requestAnimationFrame(frame);
  }
  frame();

  return {
    dispose() {
      cancelAnimationFrame(raf);
      canvas.removeEventListener('mousedown', onDown);
      window.removeEventListener('mouseup', onUp);
      window.removeEventListener('mousemove', onMove);
      canvas.removeEventListener('touchstart', onDown);
      window.removeEventListener('touchend', onUp);
      canvas.removeEventListener('touchmove', onMove);
      canvas.removeEventListener('wheel', onWheel);
      canvas.removeEventListener('keydown', onKey);
    },
  };
}
