#version 460 compatibility
#include "/lib/Settings.glsl"



varying vec2 texcoord;
flat out mat2x3 sunVec;
flat out mat2x3 lightVec;

void main() {

gl_Position = ftransform();

texcoord = gl_MultiTexCoord0.xy;

}