#version 460 compatibility
#include "/lib/Settings.glsl"

/* DRAWBUFFERS:0 */

varying vec2 texcoord;

varying vec3 color;

uniform sampler2D texture;

void main() {

vec4 albedo = texture2D(texture, texcoord);

albedo.rgb *= color;

gl_FragData[0] = albedo;
}

