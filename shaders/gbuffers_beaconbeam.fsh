#version 450 compatibility

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
layout (location = 0) out vec4 colortex0write;

varying vec2 texcoord;
uniform sampler2D texture;
varying vec4 color;
uniform sampler2D depthtex1;
uniform sampler2D depthtex0;


/* DRAWBUFFERS:0123 */

//#include "gbuffers_main.fsh"

void main() {
float depth0 = texture2D(depthtex0, texcoord).x;
vec4 albedo = texture2D(texture, texcoord);
float hand = float(texture2D(depthtex1,texcoord.xy).r < 0.56);

albedo.rgb *= (color.rgb) * 1.1;

colortex0write = albedo;

}

