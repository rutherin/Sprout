#version 450 compatibility
//#include "/lib/Utility.glsl"
////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
layout (location = 0) out vec4 colortex0write;

varying vec2 texcoord;
uniform sampler2D texture;
varying vec4 color;


/* DRAWBUFFERS:0123 */

//#include "gbuffers_main.fsh"

void main() {
vec4 albedo = texture2D(texture, texcoord);

albedo.rgb *= (color.rgb);
colortex0write = albedo;

}

