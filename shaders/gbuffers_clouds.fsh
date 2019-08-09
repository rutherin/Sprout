#version 450 compatibility

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
varying vec3 normal;
varying vec3 upVec;
varying vec3 sunVec;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 texcoord;
varying vec4 color;
uniform sampler2D texture;

float sunVisibility = clamp(dot(sunVec,upVec)+0.05,0.0,0.1)/0.1;


void main(){

	vec4 albedo = texture2D(texture, texcoord.xy);

    	float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75,0.5,1.0);

    	albedo.rgb *= 1.0 * (quarterNdotU * (0.35 * sunVisibility + 0.15));
	
	albedo.a *= 0.5 * color.a;
    
/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

}