#version 460 compatibility

uniform mat4 gbufferModelView;
varying vec2 texcoord;
varying vec3 normal;
varying vec3 upVec;
varying vec3 sunVec;
varying vec4 color;

void main(){
	normal = normalize(gl_NormalMatrix * gl_Normal);

	upVec = normalize(gbufferModelView[1].xyz);
    color = gl_Color;
}