varying vec2 texcoord;
#include "/lib/Settings.glsl"


void main() {

gl_Position = ftransform();

texcoord = gl_MultiTexCoord0.xy;

}