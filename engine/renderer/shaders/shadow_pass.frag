#version 450

// Shadow pass depth-only stub (spec §4.5 — 1024×1024 cascade).
layout(location = 0) out vec4 outDepth;

void main() {
    outDepth = vec4(1.0);
}
