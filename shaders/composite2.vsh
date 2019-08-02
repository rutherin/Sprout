#version 460 compatibility
#include "/lib/Settings.glsl"



varying vec2 texcoord;

void main() {

gl_Position = ftransform();

texcoord = gl_MultiTexCoord0.xy;

}