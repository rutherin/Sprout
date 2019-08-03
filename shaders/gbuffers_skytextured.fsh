#version 460 compatibility

uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 texcoord;
varying vec4 color;
uniform sampler2D texture;


void main(){

	vec4 albedo = texture2D(texture, texcoord.xy);

/* DRAWBUFFERS:0123 */
	gl_FragData[0] = albedo;

}