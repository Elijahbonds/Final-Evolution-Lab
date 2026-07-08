/*
 * gltfViewer.js — Tiny dependency-free glTF 2.0 viewer.
 *
 * We deliberately do NOT pull in three.js (not a frontend dep — see
 * package.json). This is a minimal raw-WebGL renderer for simple glTF meshes
 * (indexed POSITION + NORMAL, embedded data-URI buffers, one PBR-ish material)
 * with an orbit camera and ambient + directional ("HDRI-ish") lighting.
 *
 * Scope: enough to render the CC0 Study Cube and similar low-poly CC0 models.
 * Not a full glTF implementation. Falls back gracefully (throws) so callers
 * can render a static preview instead.
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
  rotateX(a) { const c=Math.cos(a),s=Math.sin(a),m=M.identity(); m[5]=c;m[6]=s;m[9]=-s;m[10]=c; return m; },
  rotateY(a) { const c=Math.cos(a),s=Math.sin(a),m=M.identity(); m[0]=c;m[2]=-s;m[8]=s;m[10]=c; return m; },
  normalMat3(m) { // upper-left 3x3 (uniform scale assumed) -> mat3
    return new Float32Array([m[0],m[1],m[2], m[4],m[5],m[6], m[8],m[9],m[10]]);
  },
};

const VERT = `
attribute vec3 aPos; attribute vec3 aNormal;
uniform mat4 uProj; uniform mat4 uView; uniform mat4 uModel; uniform mat3 uNormal;
varying vec3 vNormal;
void main(){ vNormal = normalize(uNormal * aNormal);
  gl_Position = uProj * uView * uModel * vec4(aPos,1.0); }`;

const FRAG = `
precision mediump float;
varying vec3 vNormal;
uniform vec3 uColor;
void main(){
  vec3 N = normalize(vNormal);
  // ambient + two directional lights ("HDRI-ish" fill)
  vec3 keyDir = normalize(vec3(0.5, 0.8, 0.6));
  vec3 fillDir = normalize(vec3(-0.6, 0.2, -0.4));
  float key = max(dot(N, keyDir), 0.0);
  float fill = max(dot(N, fillDir), 0.0) * 0.4;
  float ambient = 0.35;
  vec3 lit = uColor * (ambient + key + fill);
  vec3 sky = mix(vec3(0.02,0.05,0.12), vec3(0.0,0.83,1.0)*0.15, N.y*0.5+0.5);
  gl_FragColor = vec4(lit + sky, 1.0);
}`;

function compile(gl, type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src); gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS))
    throw new Error('shader: ' + gl.getShaderInfoLog(s));
  return s;
}

/**
 * Mount an interactive glTF viewer on a canvas.
 * @returns {{dispose:()=>void}}
 */
export function mountGltfViewer(canvas, gltf) {
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

  const uProj = gl.getUniformLocation(prog, 'uProj');
  const uView = gl.getUniformLocation(prog, 'uView');
  const uModel = gl.getUniformLocation(prog, 'uModel');
  const uNormal = gl.getUniformLocation(prog, 'uNormal');
  const uColor = gl.getUniformLocation(prog, 'uColor');
  gl.uniform3fv(uColor, new Float32Array(color));

  gl.enable(gl.DEPTH_TEST);
  gl.clearColor(0, 0, 0, 0);

  // orbit state
  let yaw = 0.6, pitch = 0.4, dist = 5, dragging = false, lastX = 0, lastY = 0;
  let auto = true;

  const onDown = (e) => { dragging = true; auto = false; const p = e.touches ? e.touches[0] : e; lastX = p.clientX; lastY = p.clientY; };
  const onUp = () => { dragging = false; };
  const onMove = (e) => {
    if (!dragging) return;
    const p = e.touches ? e.touches[0] : e;
    yaw += (p.clientX - lastX) * 0.01;
    pitch = Math.max(-1.3, Math.min(1.3, pitch + (p.clientY - lastY) * 0.01));
    lastX = p.clientX; lastY = p.clientY;
    if (e.touches) e.preventDefault();
  };
  const onWheel = (e) => { dist = Math.max(2.5, Math.min(12, dist + e.deltaY * 0.005)); e.preventDefault(); };

  canvas.addEventListener('mousedown', onDown);
  window.addEventListener('mouseup', onUp);
  window.addEventListener('mousemove', onMove);
  canvas.addEventListener('touchstart', onDown, { passive: false });
  window.addEventListener('touchend', onUp);
  canvas.addEventListener('touchmove', onMove, { passive: false });
  canvas.addEventListener('wheel', onWheel, { passive: false });

  let raf = 0;
  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth * dpr, h = canvas.clientHeight * dpr;
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    gl.viewport(0, 0, canvas.width, canvas.height);
  }

  function frame() {
    resize();
    if (auto) yaw += 0.006;
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    const aspect = canvas.width / Math.max(1, canvas.height);
    gl.uniformMatrix4fv(uProj, false, M.perspective(Math.PI / 4, aspect, 0.1, 100));
    let view = M.translate(0, 0, -dist);
    view = M.multiply(view, M.rotateX(pitch));
    view = M.multiply(view, M.rotateY(yaw));
    gl.uniformMatrix4fv(uView, false, view);
    const model = M.identity();
    gl.uniformMatrix4fv(uModel, false, model);
    gl.uniformMatrix3fv(uNormal, false, M.normalMat3(model));
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
    },
  };
}
